#!/usr/bin/env python3
"""
KOPIUM agent for tau3-bench — the agent uses ONLY Koru as its tool surface.

Every decision the model makes is ONE line of Koru. Nothing about what may or
may not be called is typed in this file:

  - The KORU SURFACE given to the model is `std/bridge:grammar` on the
    same GateSession Bridge that runs invocations — wire rules, register,
    inventions (440_017). The lesson and the law are the same render.
    Domain policy stays host-side (τ³ scoring), not a second Koru grammar.
  - The ARGUMENTS are the interpreter's own parse: the host-side tor stubs
    serialize the fields they received, the gate prints them as JSON on the
    OK line, and this file consumes that JSON verbatim. There is no re-parse
    of Koru here.
  - The REFUSAL is the register block answering event-denied/parse-error; a
    rejected line becomes the agent's spoken refusal, and tau3 scores the
    refusal as correct when the policy demands one.

The only tau3 spellings in this file are the mechanical name mapping
(create-task <-> create_task) and the domain config pointers — both paper-thin
transports, never a judgment about legality.

Usage:
    agent = KopiumAgent(tools=..., domain_policy=..., domain="mock", llm=...)
"""

from __future__ import annotations

import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeout
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from tau2.agent.base_agent import HalfDuplexAgent
from tau2.data_model.message import (
    AssistantMessage,
    Message,
    SystemMessage,
    UserMessage,
    ToolCall,
    ToolMessage,
    MultiToolMessage,
)
from tau2.environment.toolkit import Tool
from tau2.utils.llm_utils import generate


from gate_session import GateSession


@dataclass(frozen=True)
class DomainConfig:
    """One benchmark domain: gate binary, name map, policy rules."""

    name: str
    gate_binary: Path
    # Koru tor name -> tau3 tool name. `say` stays a Koru word.
    koru_to_tau: dict[str, str] = field(default_factory=dict)
    # No extra_rules, ever: a measured arm must be structurally incapable
    # of consuming hand-written behavioral instructions. Prose that tells
    # the model when to act is coaching, and every clause written to fix an
    # observed failure trains the test set (CONTAMINATION-2026-09-27.md).


# ---------------------------------------------------------------------------
# The domains. The register blocks (mock_tools.kz, airline_tools.kz) are the
# authority; these files only name the binaries and the tau3 spellings.
# ---------------------------------------------------------------------------

MOCK_CONFIG = DomainConfig(
    name="mock",
    gate_binary=Path(__file__).parent / "mock-gate-binary",
    koru_to_tau={
        "create-task": "create_task",
        "get-users": "get_users",
        "update-task-status": "update_task_status",
        "transfer-to-human-agents": "transfer_to_human_agents",
    },
)

AIRLINE_CONFIG = DomainConfig(
    name="airline",
    gate_binary=Path(__file__).parent / "airline-gate-binary",
    koru_to_tau={
        "get-user-details": "get_user_details",
        "get-reservation-details": "get_reservation_details",
        "list-all-airports": "list_all_airports",
        "search-direct-flight": "search_direct_flight",
        "search-onestop-flight": "search_onestop_flight",
        "get-flight-status": "get_flight_status",
        "book-reservation": "book_reservation",
        "cancel-reservation": "cancel_reservation",
        "send-certificate": "send_certificate",
        "update-reservation-flights": "update_reservation_flights",
        "update-reservation-passengers": "update_reservation_passengers",
        "update-reservation-baggages": "update_reservation_baggages",
        "transfer-to-human-agents": "transfer_to_human_agents",
        "calculate": "calculate",
    },
)

_CONFIGS = {"mock": MOCK_CONFIG, "airline": AIRLINE_CONFIG}

# `say` is the voice channel in every domain: a plain spoken message, never a
# tau3 write tool.
_SPOKEN = {"say"}

# Host verbs are introspection on the wire — `vocabulary()`, `grammar()`,
# `bind(...)`. They resolve at the gate and must NEVER marshal southbound
# as ToolCalls (tau2's env would error "unknown tool"). Their result is
# data for the model, delivered as a context note, and a turn that is
# ONLY introspection owes the user nothing yet — the model retries inside
# the same turn with the render in context.
_LOCAL = {"vocabulary", "grammar", "bind"}


class KopiumAgentState:
    """The conversation as tau3 Message objects, plus our turn count."""

    def __init__(
        self,
        system_messages: list[SystemMessage],
        messages: list[Message],
    ):
        self.system_messages = system_messages
        self.messages = messages


class KopiumAgent(HalfDuplexAgent[KopiumAgentState]):
    """A tau3 HalfDuplexAgent whose decisions all pass through the Koru gate."""

    def __init__(
        self,
        tools: list[Tool],
        domain_policy: str,
        domain: str = "mock",
        gate_binary: Optional[Path] = None,
        llm: str = "openrouter/deepseek/deepseek-v4-flash-0731",
        llm_args: Optional[dict] = None,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        if domain not in _CONFIGS:
            raise KeyError(f"unknown domain {domain!r}")
        self.domain = domain
        self.cfg = _CONFIGS[domain]
        if gate_binary is not None:
            self.cfg = DomainConfig(
                name=self.cfg.name,
                gate_binary=gate_binary,
                koru_to_tau=self.cfg.koru_to_tau,
            )
        self.llm = llm
        # reasoning_effort=none: v4-flash intermittently returns content=null
        # with output burned on reasoning_content mid-conversation (measured
        # 2026-09-26: ~15/22 replies empty at effort=low; 0/8 at none under
        # matched long-context conditions). Disabling the reasoning channel
        # forces the answer into content where the wire can read it.
        self.llm_args = {
            "timeout": 180,
            "reasoning_effort": "none",
            **(llm_args or {}),
        }
        self.call_count = 0
        self.salvage_count = 0
        self._session: Optional[GateSession] = None
        # Injected-result naming: every tool result that arrives southbound
        # re-enters the session as a bound Koru value `t{N}` — the model's
        # context shows `[t3] = {datum}` and `t3.field` resolves on the wire.
        self._bound_count = 0
        # Call-id -> the wire source line that produced it. When the env's
        # result comes back (ToolMessage.id echoes ToolCall.id) the binding
        # renders as `[tN = call-text] {datum}` — the link between datum and
        # call is structural, not positional, so a batched read can't weld
        # one reservation's fields onto another's id (measured 2026-09-27:
        # task 19 confabulated "K67C4W is EWR↔IAH round trip" from three
        # bare [tN] lines in one message).
        self._call_labels: dict[str, str] = {}
        # Effects the marshal could not carry — speech that rode beside
        # calls, earlier calls inside a chain — become "[…]" context notes
        # on the next turn. Honest feedback, never a silent drop.
        self._notes: list[str] = []

    # ------------------------------------------------------- the vocabulary
    def _ensure_session(self) -> GateSession:
        if self._session is None or not self._session.alive:
            if self._session is not None:
                self._session.close()
            self._session = GateSession(self.cfg.gate_binary)
        return self._session

    def _grammar(self) -> str:
        """`std/bridge:grammar` on the live Bridge — 440_017's derived prompt."""
        return self._ensure_session().grammar()

    def _system_prompt(self) -> str:
        grammar = self._grammar()
        if "A wire turn is one flow" not in grammar:
            raise RuntimeError("bridge grammar missing wire rules (440_017)")
        if "Your vocabulary:" not in grammar:
            raise RuntimeError("bridge grammar missing vocabulary (440_017)")
        # The tool contract doc is a GENERATED artifact (gen_*_tors.py emits
        # it from the same openai_schema the stock arm reads) — spliced
        # verbatim, never hand-edited. A domain without a generator has no
        # doc and gets none.
        doc_path = self.cfg.gate_binary.with_name(f"{self.cfg.name}_vocab_doc.md")
        doc = doc_path.read_text().strip() if doc_path.exists() else ""
        return (
            f"You are a customer service agent speaking the Koru wire language. "
            f"This is a STATE LOOP: each of your turns emits wire — one Koru "
            f"invocation per line — and tool outcomes come back as "
            f"`[tN = call] {{datum}}`: a bound Koru value, not text — the "
            f"label names the call that produced it, and `t3.user_id` "
            f"dereferences that datum on the wire. Independent calls may "
            f"share one turn — each runs, each reports; a call that needs "
            f"another call's result waits for the next turn.\n\n"
            f"## Koru (derived from this session's Bridge — 440_017)\n"
            f"{grammar}\n"
            + (f"\n{doc}\n" if doc else "")
            + f"\n## Growth — teaching the session a new verb\n"
            f"A definition is the one reply that is TWO lines: the first "
            f"line starts with `tor ` and declares the verb and its params, "
            f"the second line is its body over verbs you already hold. The "
            f"gate installs it instead of dispatching it, and the next "
            f"turn's vocabulary lists it beside the compiled verbs. Example:\n"
            f"  tor greet {{ msg: string }}\n"
            f"  greet = say(text: msg)\n\n"
            f"## Domain policy\n{self.domain_policy}"
        )

    def _refresh_vocab(self, state: KopiumAgentState) -> None:
        state.system_messages = [SystemMessage(role="system", content=self._system_prompt())]

    def get_init_state(
        self, message_history: Optional[list[Message]] = None
    ) -> KopiumAgentState:
        return KopiumAgentState(
            system_messages=[SystemMessage(role="system", content=self._system_prompt())],
            messages=list(message_history) if message_history else [],
        )

    # Progressive disclosure, minimal form: the rejection IS the disclosure
    # channel, and until now it carried almost no grammar — "not accepted:
    # {detail}" with the rejected reply never shown back. On REJECT we now
    # echo the reply and the grammar fragment: the failed verb's signature
    # when it parses to a known head, else the verb-name list.
    def _vocabulary_hint(self, reply: str) -> str:
        try:
            vocab = self._ensure_session().vocabulary()
        except Exception:
            return ""
        sigs = [l.strip() for l in vocab.splitlines()
                if l.strip() and not l.startswith("VOCAB")]
        names = ", ".join(s.split("(")[0] for s in sigs)
        heads = [m.group(1) for line in reply.splitlines()
                 if (m := re.match(r"\s*([A-Za-z_][\w-]*)", line))]
        for h in heads:
            if not any(s.startswith(h + "(") for s in sigs):
                return f"`{h}` is not a verb in your vocabulary. Your verbs: {names}.\n"
        if heads:
            s = next(s for s in sigs if s.startswith(heads[0] + "("))
            return f"`{heads[0]}` takes `{s}`.\n"
        return f"Your verbs: {names}.\n"

    @staticmethod
    def _rejection_note(detail: str, reply: str, hint: str) -> str:
        shown = f"You wrote:\n{reply}\n" if reply else ""
        return (
            f"[internal] Your last reply was not accepted: {detail}.\n"
            f"{shown}{hint}"
            f"Reply with invocations from your vocabulary — one per line."
        )

    # -------------------------------------------------------------- the gate
    def _gate(self, source: str) -> tuple[str, str]:
        """Run one Koru line through the long-lived gate. Same Bridge."""
        status, detail = self._ensure_session().send(source)
        if os.environ.get("KOPIUM_GATE_DEBUG"):
            src = " ".join(source.split())[:160]
            print(f"[gate] {status} | {detail[:200]} <- {src}", file=sys.stderr)
        return status, detail

    def _bind_result(self, content: str) -> Optional[str]:
        """Hand a tool result back to the session as bound value `t{N}`.
        Returns the name so the context render can name it; None when the
        gate refused — the render then falls back to the unbound datum,
        which is honest (a `tN` that doesn't resolve would be a lie)."""
        self._bound_count += 1
        name = f"t{self._bound_count}"
        try:
            return self._ensure_session().bind(name, content)
        except Exception:
            if os.environ.get("KOPIUM_GATE_DEBUG"):
                print(f"[gate] bind({name}) failed", file=sys.stderr)
            return None

    def close_gate(self) -> None:
        if self._session is not None:
            self._session.close()
            self._session = None

    def __del__(self) -> None:
        self.close_gate()

    @staticmethod
    def _args_from_value(value_json: str) -> dict:
        """Unpack the gate's OK payload: the tor stub serialized the parsed
        fields as a JSON string inside the interpreter's Value JSON:
        {"branch":"","value":"{...}"}. The inner string IS the args."""
        try:
            outer = json.loads(value_json)
        except json.JSONDecodeError:
            return {}
        inner = outer.get("value")
        if isinstance(inner, str):
            try:
                return json.loads(inner)
            except json.JSONDecodeError:
                return {}
        if isinstance(inner, dict):
            return inner
        return {}

    # The gate's tor declarations carry tau2's real types (i64 for the int
    # params; arrays ride as JSON inside string params and the procs splice
    # them as raw JSON), so args arrive here already Python-typed: int stays
    # int, list stays list. A literal that cannot parse to the declared type
    # is refused at the gate with a teaching error before it ever reaches
    # this boundary.

    # A held-open stream that stops mid-response defeats litellm's request
    # timeout, and a signal-based interrupt lands INSIDE litellm's retry
    # loop where it's swallowed as a transient error (both measured
    # 2026-09-25 on task 1: 30+ min wedged in an SSL read). The watchdog
    # must live outside the call: run generate in a daemon thread, give up
    # after 120s, and retry — a mid-stream stall essentially never resumes
    # (measured 2026-09-26 refresh1b: zero recoveries across 6+ stalls),
    # so a short abandon beats soaking in dead air. The abandoned thread
    # leaks its socket but the task proceeds.
    def _llm(self, messages):
        for _ in range(3):
            pool = ThreadPoolExecutor(max_workers=1)
            fut = pool.submit(
                generate,
                model=self.llm,
                messages=messages,
                **self.llm_args,
            )
            try:
                result = fut.result(timeout=120)
            except FutureTimeout:
                pool.shutdown(wait=False)
                continue
            pool.shutdown(wait=False)
            return result
        raise TimeoutError("llm call stalled after 3 attempts")

    # Conditioning junk the model leaks before the wire: reasoning tags and
    # markdown fences. Both are reply decoration, not invocation — strip
    # them so the gate judges the wire, not the wrapper. Prose stays
    # unparsed and still refuses: the gate is the judge, this is hygiene.
    @staticmethod
    def _clean_reply(text: str) -> str:
        reply = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
        reply = re.sub(r"<[^>]*>", "", reply)
        reply = reply.strip()
        if reply.startswith("```"):
            reply = re.sub(r"```(?:[a-z]*)\n?", "", reply).strip()
            reply = reply.split("```")[0].strip()
        # Blank lines are the turn terminator on the wire, not content —
        # a blank inside the reply would cut the flow early.
        return "\n".join(l for l in reply.splitlines() if l.strip())

    # Reasoning-channel salvage. reasoning_content lives on the raw provider
    # message; a line counts as wire only if it is invocation / `tor` head /
    # `|` arm / impl head — anything else means the channel held deliberation,
    # and deliberation never reaches the gate.
    @staticmethod
    def _reasoning_of(response) -> str:
        try:
            return (response.raw_data or {}).get("choices", [{}])[0] \
                .get("message", {}).get("reasoning_content") or ""
        except (AttributeError, TypeError):
            return ""

    @staticmethod
    def _is_wire_line(line: str) -> bool:
        line = line.strip()
        if not line:
            return False
        if line.startswith("tor ") or line.startswith("|"):
            return True
        if re.match(r"[A-Za-z_][\w-]*\s*\(", line):
            return True
        # impl head of a define: `name = body`
        return bool(re.match(r"[A-Za-z_][\w-]*\s*=", line))

    # Mirror of segmentTurn's boundary rules: an item opens at a non-blank
    # line that is not a `|` arm and not a `tor` define's impl head. Each
    # item records its ordered chain verbs — the head plus every `|>`
    # arm tail — because a step's wire result is always the chain's LAST
    # invocation, while the report's verb name is the head. Pairing by
    # position, not by the printed name, is what keeps `say |> cancel`
    # from being marshalled as speech carrying cancel's arguments.
    @staticmethod
    def _item_chains(reply: str) -> list[dict]:
        items: list[dict] = []
        define_name: Optional[str] = None
        for raw in reply.splitlines():
            line = raw.strip()
            if not line:
                continue
            if define_name is not None:
                if line.startswith("|") or re.match(
                    re.escape(define_name) + r"[\s=]", line
                ):
                    continue
                define_name = None
            if line.startswith("tor "):
                m = re.match(r"tor\s+([A-Za-z_][\w-]*)", line)
                define_name = m.group(1) if m else ""
                items.append({"verbs": [], "source": ""})
                continue
            if line.startswith("|"):
                arm = re.search(r"\|>\s*([A-Za-z_][\w-]*)\s*\(", line)
                if items and arm:
                    items[-1]["verbs"].append(arm.group(1))
                    items[-1]["source"] += " " + line
                continue
            m = re.match(r"([A-Za-z_][\w-]*)\s*\(", line)
            verbs = [m.group(1)] if m else []
            verbs += re.findall(r"\|>\s*([A-Za-z_][\w-]*)\s*\(", line)
            items.append({"verbs": verbs, "source": line})
        return items

    # Speech that rode inside a chain before a call (`say |> cancel`): the
    # text never reached the user. Recover it from the item's source — the
    # report only carries the tail's result.
    @staticmethod
    def _say_texts(source: str) -> list[str]:
        texts = []
        for m in re.finditer(r'say\s*\(\s*text\s*:\s*"((?:[^"\\]|\\.)*)"', source):
            try:
                texts.append(json.loads('"' + m.group(1) + '"'))
            except ValueError:
                texts.append(m.group(1))
        return texts

    @staticmethod
    def _result_text(value_json: str) -> str:
        """A host verb's OK payload carries its render inside the Value
        envelope's `value` string."""
        try:
            inner = json.loads(value_json).get("value")
        except json.JSONDecodeError:
            return value_json
        return inner if isinstance(inner, str) else json.dumps(inner)

    def _note_speech_dropped(self, text: str) -> None:
        self._notes.append(
            "[speech not delivered] the user never heard this — a turn's "
            "speech and its calls cannot travel together; the calls ran. "
            f"Say it again now, with the results: {text!r}"
        )

    def _note_calls_dropped(self, verbs: list[str]) -> None:
        self._notes.append(
            "[calls not run] a chain's earlier calls did not execute — only "
            "the last step of a flow reaches the outside: "
            f"{', '.join(verbs)}. Re-issue the ones you still need."
        )

    # A multi-item turn returns STEPS-BEGIN/<report>/STEPS-END — one line per
    # item: `step n/m result: {json}` or `step n/m <error-kind>: <msg>`.
    # Step ordinals index the turn's items, which _item_chains pairs back to
    # verb chains. Every item's LAST verb is what its result carries —
    # a non-say tail becomes a ToolCall, a say tail becomes speech.
    def _from_steps(self, reply: str, report: str) -> Optional[AssistantMessage]:
        chains = self._item_chains(reply)
        calls: list[ToolCall] = []
        spoken: list[str] = []
        for line in report.splitlines():
            m = re.match(r"step (\d+)/(\d+) ([\w-]+): (.*)$", line)
            if not m:
                continue
            n = int(m.group(1))
            kind = m.group(3)
            payload = m.group(4)
            item = chains[n - 1] if n - 1 < len(chains) else None
            if kind == "defined":
                continue  # session-side effect; the caller refreshes vocab
            if kind != "result":
                # A refused item inside a turn that otherwise ran. The
                # gate's rejection must reach the model as a note —
                # otherwise a prose line beside a real call evaporates
                # silently and the model keeps writing prose (measured
                # 2026-09-27 task 19: prose-then-call STEPS taught the
                # habit; all-prose turns then surfaced as bare apologies).
                src = (item["source"].strip() if item else "")[:120]
                self._notes.append(
                    f"[step {n} refused] {kind}: {payload} — "
                    f"\"{src}\" never ran. Anything you want the user to "
                    'hear goes through say(text: "...").'
                )
                continue
            bm = re.match(r"(.*) bound: (\S+)$", payload)
            value_json = bm.group(1) if bm else payload
            verbs = item["verbs"] if item else []
            tail = verbs[-1] if verbs else None
            if not tail:
                continue
            args = self._args_from_value(value_json)
            dropped = [v for v in verbs[:-1] if v not in _SPOKEN and v not in _LOCAL]
            if dropped:
                self._note_calls_dropped(dropped)
            if tail in _SPOKEN:
                spoken.append(str(args.get("text", "")))
            elif tail in _LOCAL:
                # Introspection never marshals southbound — its render is
                # data for the model, delivered as a context note.
                self._notes.append(
                    f"[{tail}] {self._result_text(value_json)}"
                )
                for text in self._say_texts(item["source"] if item else ""):
                    self._note_speech_dropped(text)
            else:
                for text in self._say_texts(item["source"] if item else ""):
                    self._note_speech_dropped(text)
                tau_name = self.cfg.koru_to_tau.get(tail, tail)
                call_id = f"koru_{self.call_count}_{n}"
                calls.append(ToolCall(id=call_id, name=tau_name, arguments=args))
                self._call_labels[call_id] = (item["source"] if item else tail).strip()[:160]
        # Speech + tools in one turn: a half-duplex message carries one or
        # the other, never both. The calls execute NOW — deferring them
        # behind the speech strands writes when the user stops on hearing
        # the confirmation. The speech is NOT silently dropped: the next
        # context tells the model the user never heard it and re-shows
        # the text, so the report lands the following turn, carrying real
        # results. Nothing swallowed, nothing faked.
        if calls:
            for s in spoken:
                if s:
                    self._note_speech_dropped(s)
            return AssistantMessage.text("", tool_calls=calls)
        if spoken:
            return AssistantMessage.text(" ".join(s for s in spoken if s))
        # Nothing leaves the turn — pure introspection/defines. None tells
        # the caller to deliver the notes and let the model emit again
        # inside this turn's budget.
        if self._notes:
            return None
        return AssistantMessage.text(
            "I'm sorry, I'm having trouble processing that right now. "
            "Could you tell me again what you need?"
        )

    # ------------------------------------------------------------ the loop
    def generate_next_message(
        self, message: UserMessage, state: KopiumAgentState
    ) -> tuple[AssistantMessage, KopiumAgentState]:
        self.call_count += 1

        # tau3 alternates user turns with tool results. A ToolMessage is DB
        # output, not something the user said — and not opaque text either:
        # each result is bound into the session as `t{N}` BEFORE the model
        # sees it, so the context line names a value the wire can actually
        # dereference (`t1.user_id`) rather than a JSON blob to re-type.
        if isinstance(message, ToolMessage):
            name = self._bind_result(message.content)
            label = self._call_labels.get(getattr(message, "id", None) or "")
            if name:
                src = f" = {label}" if label else ""
                shown = f"[{name}{src}] {message.content}"
            else:
                shown = f"[tool result] {message.content}"
            state.messages.append(UserMessage.text(shown))
        elif isinstance(message, MultiToolMessage):
            # A multi-item turn's results arrive together, one per step.
            # Each line names BOTH the binding and the call that produced
            # it — the datum→call link is written in the label, so the
            # model never has to correlate three blobs positionally.
            lines = []
            for tm in message.tool_messages:
                name = self._bind_result(tm.content)
                label = self._call_labels.get(getattr(tm, "id", None) or "")
                if name:
                    src = f" = {label}" if label else ""
                    lines.append(f"[{name}{src}] {tm.content}")
                else:
                    lines.append(f"[tool result] {tm.content}")
            state.messages.append(UserMessage.text("\n".join(lines) + "\n"))
        else:
            state.messages.append(message)

        # Effects the marshal could not carry last turn — undelivered
        # speech, un-dispatched chain calls — are surfaced now as context
        # notes, same channel as rejection feedback.
        if self._notes:
            for note in self._notes:
                state.messages.append(UserMessage.text(note))
            self._notes = []

        # 1. Ask the model for wire Koru. No tools are offered — the only
        #    "tool schema" the model sees is the register block render.
        #    Measured 2026-09-25 (smoke, tasks 1/2): the dominant failure is
        #    the model drifting off-wire — <think> tags, prose — and each
        #    refusal burned a whole turn AND leaked gate jargon to the user.
        #    So: strip conditioning junk before the gate, and let the
        #    rejection teach inside the turn up to 3 times rather than once.
        status = detail = ""
        # Token/cost accounting across the whole turn, not just the accepted
        # attempt: every litellm call in the retry loop burns real spend, and
        # none of it was reaching res.messages (the translated `out` carried
        # usage=None, so the CSV's koru token/cost columns measured only the
        # user simulator — a ~6x phantom efficiency). Sum all attempts.
        turn_usage: dict = {"prompt_tokens": 0, "completion_tokens": 0}
        turn_cost = 0.0
        saw_usage = False
        saw_cost = False
        for attempt in range(3):
            dump_dir = os.environ.get("KOPIUM_CONTEXT_DUMP")
            if dump_dir:
                # Snapshot the exact context the model sees at this attempt —
                # enables post-hoc replay probes without re-running the task.
                dump = [{"kind": type(m).__name__,
                         "content": getattr(m, "content", None)}
                        for m in state.system_messages + state.messages]
                Path(dump_dir).mkdir(parents=True, exist_ok=True)
                Path(dump_dir, f"ctx_{self.call_count:02d}_{attempt}.json").write_text(
                    json.dumps(dump, indent=1))
            try:
                response = self._llm(state.system_messages + state.messages)
                if response.usage:
                    turn_usage["prompt_tokens"] += response.usage.get("prompt_tokens", 0)
                    turn_usage["completion_tokens"] += response.usage.get("completion_tokens", 0)
                    saw_usage = True
                if response.cost is not None:
                    turn_cost += response.cost
                    saw_cost = True
            except TimeoutError:
                # Provider stall, not a wire failure — degrade like an empty
                # reply so the turn's retry loop absorbs it and the task
                # survives (measured 2026-09-26 refresh1: 3 consecutive
                # stalls crashed task 1 outright).
                if os.environ.get("KOPIUM_GATE_DEBUG"):
                    print(f"[gate] STALL attempt {attempt + 1}/3", file=sys.stderr)
                status, detail = "REJECT", "the llm call stalled"
                reply = ""
                state.messages.append(
                    UserMessage.text(
                        self._rejection_note(detail, reply, "")
                    )
                )
                continue
            reply = self._clean_reply(response.content or "")
            if not reply:
                # v4-flash quirk, measured 2026-09-26: under long context the
                # answer sometimes lands in reasoning_content with content
                # null (shot 3/6 repro: reasoning WAS the wire line). Salvage
                # only when the reasoning IS a clean wire turn — every line
                # invocation/arm/define — else deliberation would dispatch.
                rc = self._clean_reply(self._reasoning_of(response))
                if rc and all(self._is_wire_line(l) for l in rc.splitlines()):
                    reply = rc
                    self.salvage_count += 1
            if not reply:
                # Nothing on the wire — don't spend a gate round-trip.
                status, detail = "REJECT", "the reply was empty"
                if os.environ.get("KOPIUM_GATE_DEBUG"):
                    raw = (response.content or "")[:200].replace("\n", " ")
                    print(f"[gate] EMPTY raw={raw!r}", file=sys.stderr)
            else:
                status, detail = self._gate(reply)
            if status == "DEFINED":
                self._refresh_vocab(state)
                out = AssistantMessage.text(f"defined {detail}")
                out.usage = turn_usage if saw_usage else None
                out.cost = turn_cost if saw_cost else None
                state.messages.append(AssistantMessage.text(reply))
                return out, state
            if status == "OK":
                # A lone introspection call (`vocabulary()`, `bind(...)`,
                # `grammar()`) never leaves the gate — its render is data
                # for the model, not a message for the user. Deliver it as
                # a context note and let the model answer in this turn.
                _vn, _vb, _vj = GateSession.parse_ok(detail)
                _ch = self._item_chains(reply)
                _vs = _ch[0]["verbs"] if _ch else []
                if (_vs[-1] if _vs else _vn) in _LOCAL:
                    state.messages.append(AssistantMessage.text(reply))
                    self._notes.append(
                        f"[{_vs[-1] if _vs else _vn}] "
                        f"{self._result_text(_vj)}"
                    )
                    dropped = [v for v in _vs[:-1]
                               if v not in _SPOKEN and v not in _LOCAL]
                    if dropped:
                        self._note_calls_dropped(dropped)
                    if _ch:
                        for s in self._say_texts(_ch[0]["source"]):
                            self._note_speech_dropped(s)
                    for note in self._notes:
                        state.messages.append(UserMessage.text(note))
                    self._notes = []
                    continue
                break
            if status == "STEPS":
                if "defined:" in detail:
                    self._refresh_vocab(state)
                out = self._from_steps(reply, detail)
                if out is None:
                    # The whole turn was introspection — nothing for the
                    # user or the env. Deliver the renders as context notes
                    # and let the model answer inside this turn's budget.
                    state.messages.append(AssistantMessage.text(reply))
                    for note in self._notes:
                        state.messages.append(UserMessage.text(note))
                    self._notes = []
                    continue
                out.usage = turn_usage if saw_usage else None
                out.cost = turn_cost if saw_cost else None
                state.messages.append(AssistantMessage.text(reply))
                return out, state
            state.messages.append(
                UserMessage.text(
                    self._rejection_note(detail, reply, self._vocabulary_hint(reply))
                )
            )

        if status == "OK":
            event_name, _bound, value_json = GateSession.parse_ok(detail)
            # An armed single-item turn (`say |> cancel`) reports the HEAD
            # verb while the value is the chain's TAIL result — classify by
            # the tail the same way _from_steps does, or a "speak then act"
            # line marshals as speech carrying the action's arguments.
            chains = self._item_chains(reply)
            verbs = chains[0]["verbs"] if chains else []
            name = verbs[-1] if verbs else event_name
            dropped = [v for v in verbs[:-1] if v not in _SPOKEN and v not in _LOCAL]
            if dropped:
                self._note_calls_dropped(dropped)
            if name in _LOCAL:
                # Reachable only when every retry attempt was introspection
                # — the loop consumed the budget delivering renders.
                out = AssistantMessage.text(
                    "I'm sorry, I'm having trouble processing that right now. "
                    "Could you tell me again what you need?"
                )
            elif name in _SPOKEN:
                args = self._args_from_value(value_json)
                text = str(args.get("text", ""))
                out = AssistantMessage.text(text)
            else:
                if chains:
                    for s in self._say_texts(chains[0]["source"]):
                        self._note_speech_dropped(s)
                tau_name = self.cfg.koru_to_tau.get(name, name)
                args = self._args_from_value(value_json)
                call_id = f"koru_{self.call_count}_{name}"
                self._call_labels[call_id] = reply.strip()[:160]
                out = AssistantMessage.text(
                    "", tool_calls=[ToolCall(id=call_id, name=tau_name, arguments=args)]
                )
        else:
            # Three rejections in a turn: the model cannot find the wire.
            # Refuse plainly — gate internals ("not an invocation: ...") are
            # a wire-side concern, not something the user should ever see.
            out = AssistantMessage.text(
                "I'm sorry, I'm having trouble processing that right now. "
                "Could you tell me again what you need?"
            )

        # tau2 requires content or tool_calls — an empty say() or an empty
        # spoken join would build an invalid message.
        if not out.content and not out.tool_calls:
            out = AssistantMessage.text(
                "I'm sorry, I'm having trouble processing that right now. "
                "Could you tell me again what you need?"
            )

        # The model's memory is the wire it emitted, not the tau2 message we
        # translated it into — remembering `AssistantMessage(tool_calls=...)`
        # with empty content taught v4-flash to answer with empty content
        # (measured 2026-09-26: ~12 empty replies/task under long context,
        # 0/8 in a history that kept the wire).
        state.messages.append(AssistantMessage.text(reply if reply else out.content or ""))
        out.usage = turn_usage if saw_usage else None
        out.cost = turn_cost if saw_cost else None
        return out, state