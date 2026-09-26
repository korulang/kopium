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
    # Extra policy rules for the system prompt (domain-specific, prose).
    extra_rules: list[str] = field(default_factory=list)


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
    extra_rules=[
        "Check what has already been done before acting. When a task is "
        "already created or resolved in the tool results, do NOT call the "
        "tool again — confirm to the user via say(text: ...).",
        "Never repeat a tool call that already succeeded with the same "
        "purpose.",
        "Only pass arguments the user actually gave you. Never invent an "
        "optional argument (like a description the user never mentioned).",
    ],
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
    extra_rules=[
        "The cancellation API does NOT check whether cancellation is allowed. "
        "YOU must apply the policy before calling cancel-reservation. When the "
        "policy forbids it (more than 24 hours after booking, no insurance "
        "covering the reason, portion already flown), refuse via say(text: ...) "
        "and do NOT call cancel-reservation.",
        "Structured arguments (flights, passengers, payment_methods) are JSON: "
        "write them as a single string argument containing a JSON array/object.",
        "Only pass arguments the user actually gave you.",
    ],
)

_CONFIGS = {"mock": MOCK_CONFIG, "airline": AIRLINE_CONFIG}

# `say` is the voice channel in every domain: a plain spoken message, never a
# tau3 write tool.
_SPOKEN = {"say"}


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
                extra_rules=self.cfg.extra_rules,
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
        rules = "\n".join(f"- {r}" for r in self.cfg.extra_rules)
        literal_rules = (
            "- If you cannot or must not do what the user asks, call "
            "say(text: ...) with the honest reason, and call NO tool."
        )
        return (
            f"You are a customer service agent speaking the Koru wire language. "
            f"This is a STATE LOOP: each of your turns emits wire — one Koru "
            f"invocation per line — and the outcome comes back as "
            f"`[tool result] ...`. INDEPENDENT reads belong in ONE turn: "
            f"checking five reservations is five lines in one reply, not five "
            f"turns. Dependent steps stay serial — never emit a call that needs "
            f"another call's result in the same turn. Read, decide, act, or "
            f"refuse via say(text: ...).\n\n"
            f"## Koru (derived from this session's Bridge — 440_017)\n"
            f"{grammar}\n\n"
            f"## Happy path — batch the reads, then act\n"
            f"When several lookups are independent (e.g. inspecting each "
            f"reservation a user holds), put them ALL in one reply:\n"
            f"  you:   get-reservation-details(reservation_id: \"R1\")\n"
            f"         get-reservation-details(reservation_id: \"R2\")\n"
            f"         get-reservation-details(reservation_id: \"R3\")\n"
            f"All three results come back together. Then, when you hold what "
            f"you need, act:\n"
            f"  you:   cancel-reservation(reservation_id: \"...\")\n"
            f"Do NOT jump straight to a write. Read the state you need, let the "
            f"policy decide, then act — or refuse via say(text: ...).\n\n"
            f"Booking is also a chain — gather the flight, then book with "
            f"structured args as a single JSON string:\n"
            f"  you: search-direct-flight(origin: \"JFK\", destination: \"SEA\", "
            f"date: \"2024-06-01\")\n"
            f"  you: book-reservation(user_id: \"U1\", origin: \"JFK\", "
            f"destination: \"SEA\", flight_type: \"one-way\", cabin: \"economy\", "
            f"flights: \"[{{\\\"flight_number\\\": \\\"HAT123\\\"}}]\", "
            f"passengers: \"[{{\\\"name\\\": \\\"Mei Garcia\\\"}}]\", "
            f"payment_methods: \"[{{\\\"id\\\": \\\"PM1\\\"}}]\", "
            f"insurance: \"false\")\n"
            f"The reads give you the ids to fill the write. Structured args are "
            f"JSON-as-string; use escaped quotes inside.\n\n"
            f"## Growth — teaching the session a new verb\n"
            f"A definition is the one reply that is TWO lines: the first "
            f"line starts with `tor ` and declares the verb and its params, "
            f"the second line is its body over verbs you already hold. The "
            f"gate installs it instead of dispatching it, and the next "
            f"turn's vocabulary lists it beside the compiled verbs. Example:\n"
            f"  tor greet {{ msg: string }}\n"
            f"  greet = say(text: msg)\n\n"
            f"## Domain policy\n{self.domain_policy}\n\n"
            f"## Rules\n{rules}\n{literal_rules}"
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

    # -------------------------------------------------------------- the gate
    def _gate(self, source: str) -> tuple[str, str]:
        """Run one Koru line through the long-lived gate. Same Bridge."""
        status, detail = self._ensure_session().send(source)
        if os.environ.get("KOPIUM_GATE_DEBUG"):
            src = " ".join(source.split())[:160]
            print(f"[gate] {status} | {detail[:200]} <- {src}", file=sys.stderr)
        return status, detail

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
    # item contributes one entry — its verb name, or None for defines and
    # unparseable lines — so report ordinals index this list directly.
    @staticmethod
    def _item_names(reply: str) -> list[Optional[str]]:
        names: list[Optional[str]] = []
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
                names.append(None)
                continue
            if line.startswith("|"):
                continue
            m = re.match(r"([A-Za-z_][A-Za-z0-9_-]*)\s*\(", line)
            names.append(m.group(1) if m else None)
        return names

    # A multi-item turn returns STEPS-BEGIN/<report>/STEPS-END — one line per
    # item: `step n/m result: {json}` or `step n/m <error-kind>: <msg>`.
    # Step ordinals index the turn's items, which _item_names pairs back to
    # verb names. Every ran step that produced a value becomes a ToolCall —
    # parallel calls in one message, the same shape stock agents emit
    # (tau2's executor runs them all).
    def _from_steps(self, reply: str, report: str) -> AssistantMessage:
        names = self._item_names(reply)
        calls: list[ToolCall] = []
        spoken: list[str] = []
        for line in report.splitlines():
            m = re.match(r"step (\d+)/(\d+) result: (.*)", line)
            if not m:
                continue
            n = int(m.group(1))
            name = names[n - 1] if n - 1 < len(names) else None
            if not name:
                continue
            args = self._args_from_value(m.group(3))
            if name in _SPOKEN:
                spoken.append(str(args.get("text", "")))
            else:
                tau_name = self.cfg.koru_to_tau.get(name, name)
                calls.append(
                    ToolCall(id=f"koru_{self.call_count}_{n}", name=tau_name, arguments=args)
                )
        if calls:
            return AssistantMessage.text("", tool_calls=calls)
        if spoken:
            return AssistantMessage.text(" ".join(s for s in spoken if s))
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
        # output, not something the user said: label it the way the wire's
        # [tool result] convention does.
        if isinstance(message, ToolMessage):
            shown = f"[tool result] {message.content}"
            state.messages.append(UserMessage.text(shown))
        elif isinstance(message, MultiToolMessage):
            # A multi-item turn's results arrive together, one per step.
            shown = "".join(f"[tool result] {tm.content}\n" for tm in message.tool_messages)
            state.messages.append(UserMessage.text(shown))
        else:
            state.messages.append(message)

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
                        f"[internal] Your last reply was not accepted: {detail}. "
                        f"Reply with invocations from your vocabulary — one per line."
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
                break
            if status == "STEPS":
                if "defined:" in detail:
                    self._refresh_vocab(state)
                out = self._from_steps(reply, detail)
                out.usage = turn_usage if saw_usage else None
                out.cost = turn_cost if saw_cost else None
                state.messages.append(AssistantMessage.text(reply))
                return out, state
            state.messages.append(
                UserMessage.text(
                    f"[internal] Your last reply was not accepted: {detail}. "
                    f"Reply with invocations from your vocabulary — one per line."
                )
            )

        if status == "OK":
            event_name, _, value_json = detail.partition(" ")
            if event_name in _SPOKEN:
                args = self._args_from_value(value_json)
                text = str(args.get("text", ""))
                out = AssistantMessage.text(text)
            else:
                tau_name = self.cfg.koru_to_tau.get(event_name, event_name)
                args = self._args_from_value(value_json)
                out = AssistantMessage.text(
                    "", tool_calls=[ToolCall(id=f"koru_{self.call_count}_{event_name}", name=tau_name, arguments=args)]
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