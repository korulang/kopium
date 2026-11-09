#!/usr/bin/env python3
"""AirlineLladaAgent — local LLaDA2.2-mini driving the REAL KOPIUM gate.

Unlike LocalLladaAgent (mock: wire→ToolCall mapping, gate as validator),
the airline gate IS the tool-call engine (tau_wire.kz protocol): tool
tors emit {"kind":"call"} and block for {"kind":"result"}; say() emits
{"kind":"say"} and blocks for {"kind":"user"}. One wire program can span
many tau2 exchanges — the gate stays mid-execution while the orchestrator
shuttles user replies and tool results.

State machine per generate_next_message:
  program open + incoming msg  -> translate to gate JSON, pump to next
                                 emittable (call/say/status)
  call event                   -> AssistantMessage.tool_calls (gate's own
                                 tau2 name + args — no mapping needed)
  say event                    -> AssistantMessage.text
  status (OK/HALT/REJECT/...)  -> program verdict observed; if it was a
                                 rejection, regenerate bounded; else the
                                 program is done -> generate the next one
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

from tau2.agent.base_agent import HalfDuplexAgent
from tau2.data_model.message import (
    AssistantMessage,
    Message,
    SystemMessage,
    ToolCall,
    ToolMessage,
    MultiToolMessage,
    UserMessage,
)
from tau2.environment.toolkit import Tool

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from tau_gate_session import TauGateSession  # noqa: E402
from local_llada_agent import (  # noqa: E402
    NGRAM_VENV_PY, GEN_SERVER, LocalAgentState,
)


class AirlineAgentState(LocalAgentState):
    pass


class AirlineLladaAgent(HalfDuplexAgent[AirlineAgentState]):
    def __init__(
        self,
        tools: list[Tool],
        domain_policy: str,
        gate_binary: Path,
        *,
        arm: str = "base",
        draft: Optional[str] = None,
        construct: Optional[str] = None,
        draft_temperature: float = 1.0,
        draft_frac: float = 0.5,
        draft_blocks: int = 0,
        blank_values: bool = False,
        noise_draft: bool = False,
        steps: int = 16,
        max_tokens: int = 256,
        temperature: float = 0.0,
        retry_temperature: float = 0.0,
        max_rejects: int = 6,
        seed: int = 0,
        rlog=None,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        self.gate = TauGateSession(Path(gate_binary))
        self.rlog = rlog
        self.gen = subprocess.Popen(
            [str(NGRAM_VENV_PY), str(GEN_SERVER)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        self.arm = arm
        self.draft = draft if arm == "warm" else None
        self.construct = construct if arm == "warm" else None
        self.draft_temperature = draft_temperature
        self.draft_frac = draft_frac
        self.draft_blocks = draft_blocks
        self.blank_values = blank_values
        self.noise_draft = noise_draft
        self.steps = steps
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.retry_temperature = retry_temperature
        self.max_rejects = max_rejects
        self.seed = seed
        self.call_count = 0
        self.gen_calls = 0
        self.rejections = 0
        self.system_text = ""
        self.trace: list[str] = []

    def _ev(self, type_: str, **fields) -> None:
        if self.rlog is not None:
            self.rlog.event(type_, **fields)

    # ------------------------------------------------------------- plumbing
    def _gen(self, messages: list[dict], temperature: float | None = None) -> dict:
        req = {
            "messages": messages,
            "max_tokens": self.max_tokens,
            "steps": self.steps,
            "temperature": self.temperature if temperature is None else temperature,
            "arm": self.arm,
            "seed": self.seed + self.gen_calls,
        }
        if self.draft_blocks:
            req["draft_blocks"] = self.draft_blocks
        if self.construct:
            req["construct"] = self.construct
            req["draft_frac"] = self.draft_frac
            if self.blank_values:
                req["blank_values"] = True
            if self.noise_draft:
                req["noise_draft"] = True
        elif self.draft:
            req["draft"] = self.draft
            req["draft_temperature"] = self.draft_temperature
            req["draft_frac"] = self.draft_frac
        assert self.gen.stdin is not None and self.gen.stdout is not None
        self.gen.stdin.write(json.dumps(req) + "\n")
        self.gen.stdin.flush()
        line = self.gen.stdout.readline()
        if not line:
            raise RuntimeError("gen_server died")
        resp = json.loads(line)
        if "error" in resp:
            raise RuntimeError(f"gen_server: {resp['error']}")
        self.gen_calls += 1
        self._ev(
            "gen", n=self.gen_calls,
            temperature=self.temperature if temperature is None else temperature,
            messages=messages, response=resp,
        )
        return resp

    @staticmethod
    def _clean_wire(text: str) -> str:
        import re
        wire = text.strip()
        if wire.startswith("```"):
            wire = wire.split("\n", 1)[-1] if "\n" in wire else ""
            wire = wire.rsplit("```", 1)[0]
        # drop non-invocation lines — bigger models leak thinking-channel
        # artifacts ("thought", "note: prose") that aren't wire; every
        # legal wire line contains an invocation `verb(`
        wire = "\n".join(
            ln.rstrip() for ln in wire.splitlines()
            if ln.strip() and "(" in ln
        )
        # systematic model tic: say(text: "...")") — a stray `")` after the
        # closing paren rejects the whole turn. Collapse trailing
        # quote+paren runs to a single `")`.
        wire = re.sub(r'"\)+$', '")', wire)
        return wire

    def _observe(self, state: AirlineAgentState, role: str, text: str) -> None:
        state.transcript.append({"role": role, "content": text})
        self._ev("observe", role=role, content=text)

    @staticmethod
    def _parse_bound_json(detail: str):
        """`say bound=r2 {"branch":..,"value":..}` -> (event, bound, value).
        Gate status details carry the bound name and a JSON envelope —
        incumbent transcript format is `result: <value> bound: <name>`."""
        m = re.match(r"([\w-]+)\s+bound=(\S+)\s+(\{.*\})\s*$", detail, re.S)
        if not m:
            return None
        try:
            val = json.loads(m.group(3)).get("value")
        except Exception:
            return None
        return m.group(1), m.group(2), val

    def _observe_ok(self, state: AirlineAgentState, detail: str) -> None:
        parsed = self._parse_bound_json(detail)
        if parsed is None:
            self._observe(state, "user", f"result: {detail}")
            return
        event, bound, val = parsed
        if event == "say":
            # a say's bound value IS the user's reply — surface it as a
            # user message, not gate JSON (incumbent observe-human parity)
            self._observe(state, "user", f"user: {val}")
        else:
            self._observe(state, "user", f"result: {val} bound: {bound}")

    def _fmt_step(self, line: str) -> str:
        """`step 2/3 result: {json} bound: r4` -> `result: <value> bound: r4`."""
        m = re.match(r"step\s+\S+\s+result:\s+(\{.*\})\s+bound:\s+(\S+)", line, re.S)
        if m:
            try:
                val = json.loads(m.group(1)).get("value")
                return f"result: {val} bound: {m.group(2)}"
            except Exception:
                pass
        return f"result: {line}"

    # ------------------------------------------------------------- the pump
    def _pump(self, ev, state: AirlineAgentState):
        """One gate event -> ('emit', AssistantMessage) | ('done',) |
        ('reject', obs). Status verdicts observed; call/say become messages.
        Empty says are skipped — an AssistantMessage with no content and
        no tool_calls fails tau2 validation."""
        while True:
            kind = ev[0]
            if kind == "call":
                obj = ev[1]
                note = " [malformed args salvaged]" if obj.get("_malformed_args") else ""
                self.trace.append(f"  [call ] {obj.get('name')} {obj.get('arguments')}{note}")
                self._ev("gate_call", id=obj.get("id", ""), name=obj.get("name", ""),
                         arguments=obj.get("arguments") or {})
                tc = ToolCall(
                    id=obj.get("id", ""),
                    name=obj.get("name", ""),
                    arguments=obj.get("arguments") or {},
                )
                return ("emit", AssistantMessage.text("", tool_calls=[tc]))
            if kind == "say":
                text = str(ev[1].get("text", ""))
                if not text.strip():
                    # say() BLOCKS for a user reply on this gate — skipping
                    # the emit without answering deadlocks the program.
                    # An empty say carries nothing to reply to: feed "" so
                    # the binding resolves and the program moves on.
                    self.trace.append("  [say  ] (empty — auto-replied)")
                    ev = self.gate.feed_user("")
                    continue
                self.trace.append(f"  [say  ] {text[:200]}")
                self._ev("gate_say", text=text)
                return ("emit", AssistantMessage.text(text))
            if kind == "eof":
                raise RuntimeError("gate closed mid-program")
            # status verdict
            status, detail = ev[1], ev[2]
            self.trace.append(f"  [gate ] {status} {detail[:300]}")
            self._ev("gate_status", status=status, detail=detail)
            if status == "STEPS":
                for ln in detail.splitlines():
                    if ln.strip():
                        self._observe(state, "user", self._fmt_step(ln.strip()))
            elif status == "OK":
                self._observe_ok(state, detail)
            elif status == "DEFINED":
                self._observe(state, "user", f"defined: {detail}")
            elif status == "HALT":
                obs = f"unhandled-branch: {detail}"
                self._observe(state, "user", obs)
                return ("reject", obs)
            else:  # REJECT / ERROR
                obs = detail if status == "REJECT" else f"{status.lower()}: {detail}"
                self._observe(state, "user", obs)
                return ("reject", obs)
            return ("done",)

    def _run_program(self, wire: str, state: AirlineAgentState):
        """Send wire, pump events until an emittable message or the
        program closes. Returns ('emit', AssistantMessage) after at most
        one call/say — later events arrive on subsequent calls."""
        self._ev("wire", text=wire)
        ev = self.gate.send_wire(wire)
        out = self._pump(ev, state)
        if out[0] == "done":
            return ("done",)
        return out

    # ------------------------------------------------------------- tau2 side
    def get_init_state(self, message_history=None):
        grammar = self.gate.grammar()
        policy_block = (
            "\n\nDOMAIN POLICY — the rules every action must satisfy. Judge "
            "each request against these conditions, reading them against the "
            "records you fetch.\n\n" + self.domain_policy
        )
        self.system_text = grammar + policy_block
        self._ev("system", text=self.system_text)
        state = AirlineAgentState(
            [SystemMessage(role="system", content=self.system_text)],
            list(message_history or []),
        )
        # seed: incumbent's tau_wire:seed-text — ONE assistant turn that
        # demonstrates call -> arm-bind -> say in a single program. A
        # greeting-only seed teaches say-only; this teaches the lookup
        # shape every airline task opens with.
        state.transcript.append({
            "role": "assistant",
            "content": 'get-user-details(user_id: "example_user_0") | ok u |>\n'
                       'say(text: "Welcome back, {{ u.user_id }} — membership {{ u.membership }}.")',
        })
        # the Oct-2 gate binary deadlocks completing multi-line turns —
        # generated wires are split into single-line flows and sent one
        # per turn (see _flows). Queue holds not-yet-sent flows.
        state.pending_flows = []
        return state

    def _ingest(self, message: Message, state: AirlineAgentState) -> None:
        if isinstance(message, UserMessage):
            self._observe(state, "user", f"user: {message.content}")
        elif isinstance(message, MultiToolMessage):
            for tm in message.tool_messages:
                self._ingest_tool(tm, state)
        elif isinstance(message, ToolMessage):
            self._ingest_tool(message, state)

    def _ingest_tool(self, tm: ToolMessage, state: AirlineAgentState) -> None:
        # ToolMessages are marshal plumbing — the gate reports results
        # itself in incumbent format (`result: <value> bound: rN`) when
        # the program's status arrives. Observing the raw envelope here
        # double-reports and wraps the value in {"content":...} noise.
        content = tm.content or ""
        self.trace.append(f"  [tool ] {tm.id} -> {content[:200]}")

    @staticmethod
    def _flows(wire: str) -> list[str]:
        """Split generated wire into flows, each collapsed to ONE line.

        The Oct-2 airline-gate-binary deadlocks when a turn spans
        multiple lines (verified: single-line chains/arms verdict OK;
        the same program across two lines hangs forever after the last
        item). Items are line-separated; a flow continues while the
        previous line ends with `|>` (arm bind awaiting its continuation
        invocation) or the next line starts with `|` (arm on own line).
        Joining a flow's lines with a space yields valid wire — proven
        against the binary (`call | ok u |> say(...)` -> OK)."""
        flows: list[str] = []
        cur: list[str] = []
        for ln in wire.splitlines():
            s = ln.strip()
            if not s:
                continue
            if cur and (s.startswith("|") or cur[-1].rstrip().endswith("|>")):
                cur.append(s)
            else:
                if cur:
                    flows.append(" ".join(cur))
                cur = [s]
        if cur:
            flows.append(" ".join(cur))
        return flows or [wire]

    def _msgs(self, state: AirlineAgentState) -> list[dict]:
        return [{"role": "system", "content": self.system_text}] + state.transcript

    def _feed_and_pump(self, message: Message, state: AirlineAgentState):
        """Route the incoming tau2 message to whatever the gate awaits.
        gate.awaiting is the truth: 'say' wants user text, 'call' wants a
        result. Anything else is a protocol mismatch — fail loud, never
        desync the gate."""
        await_kind = self.gate.awaiting
        if isinstance(message, MultiToolMessage):
            if await_kind != "call":
                return ("mismatch", f"tool results while awaiting {await_kind}")
            ev = None
            for tm in message.tool_messages:
                ev = self.gate.feed_result(
                    tm.id or "", tm.content or "", bool(tm.error)
                )
                out = self._pump(ev, state)
                if out[0] != "done":
                    return out
            return ("done",)
        if isinstance(message, ToolMessage):
            if await_kind != "call":
                return ("mismatch", f"tool result while awaiting {await_kind}")
            ev = self.gate.feed_result(
                message.id or "", message.content or "", bool(message.error)
            )
        elif isinstance(message, UserMessage):
            if await_kind == "call":
                # callIO would pend the text but emit no event — the pump
                # would block on readline forever. Anomalous in half-duplex.
                return ("mismatch", "user text while call outstanding")
            ev = self.gate.feed_user(message.content or "")
        else:
            return ("mismatch", f"unhandled {type(message).__name__} while awaiting {await_kind}")
        return self._pump(ev, state)

    def _resume_open_program(self, message: Message, state: AirlineAgentState):
        """Gate is blocked — feed the message, pump to next event.
        -> ('emit',msg) | ('done',) | ('reject',) | ('mismatch',why)."""
        out = self._feed_and_pump(message, state)
        if out[0] == "mismatch":
            raise RuntimeError(
                f"gate awaiting {self.gate.awaiting} but tau2 sent "
                f"{type(message).__name__}: {out[1]}"
            )
        if out[0] == "reject":
            self.rejections += 1
        return out

    def generate_next_message(self, message, state: AirlineAgentState):
        self.call_count += 1
        self._ingest(message, state)

        # Resume a blocked program: the gate is awaiting a say-reply or
        # tool result — this message is protocol input, not a new turn.
        if self.gate.awaiting is not None:
            out = self._resume_open_program(message, state)
            if out[0] == "emit":
                state.messages.append(out[1])
                return out[1], state
            # done -> program closed; reject -> program died. Either way
            # the gate is back at intake — fall through to generation.

        # Drain queued flows from a multi-flow generation — one flow per
        # gate turn (the binary deadlocks multi-line turns). Each queued
        # flow is an independent program: emit -> return, done/reject ->
        # next queued flow, empty queue -> normal generation resumes.
        while getattr(state, "pending_flows", None) and self.gate.awaiting is None:
            flow = state.pending_flows.pop(0)
            self._observe(state, "assistant", flow)
            self.trace.append(f"  [flow ] {flow[:200]}")
            self._ev("flow", text=flow)
            out = self._run_program(flow, state)
            if out[0] == "emit":
                state.messages.append(out[1])
                return out[1], state
            if out[0] == "reject":
                self.rejections += 1
                self._ev("reject", reason=out[1], source="flow")
            # done or rejected-and-closed: loop sends the next queued flow

        # Generate programs until one emits something user/tool-visible.
        # Rejection retries escalate to retry_temperature — at temp 0 the
        # same context regenerates the identical rejected wire forever.
        for attempt in range(self.max_rejects):
            temp = self.retry_temperature if attempt > 0 else None
            resp = self._gen(self._msgs(state), temperature=temp)
            wire = self._clean_wire(resp.get("text", ""))
            self.trace.append(
                f"  [resp ] wall={resp.get('wall_s')}s tok={resp.get('gen_tokens')} "
                f"draft={resp.get('draft_positions')}/{resp.get('draft_revisions')}"
            )
            if not wire:
                self._observe(
                    state, "user",
                    "your reply carried no wire — emit wire text: "
                    '`say(text: ...)` reaches the user, `verb(field: ...)` calls',
                )
                self._ev("reject", reason="empty-wire", attempt=attempt)
                continue
            flows = self._flows(wire)
            if len(flows) > 1:
                state.pending_flows = flows[1:] + list(
                    getattr(state, "pending_flows", [])
                )
                wire = flows[0]
                self.trace.append(f"  [split] {len(flows)} flows, queued {len(flows)-1}")
            self._observe(state, "assistant", wire)
            self.trace.append(f"  [wire ] {wire[:400]}")
            # HARD INVARIANT: never send wire while the gate is blocked on
            # say/call — source lines hit the JSON reader and panic it.
            if self.gate.awaiting is not None:
                raise RuntimeError(
                    f"refusing wire send: gate awaiting {self.gate.awaiting}"
                )
            out = self._run_program(wire, state)
            if out[0] == "emit":
                state.messages.append(out[1])
                return out[1], state
            if out[0] == "reject":
                self.rejections += 1
                self._ev("reject", reason=out[1], attempt=attempt)
                continue
            # done with no emit (program of only host verbs / empty say)
            self._observe(
                state, "user",
                "that reply reached nobody — `say(text: ...)` reaches the "
                "user, `verb(field: ...)` calls",
            )
            continue

        raise RuntimeError(
            f"agent wire loop exhausted ({self.max_rejects} rejections)"
        )

    def stop(self, message=None, state=None):
        self.gate.close()
        try:
            if self.gen.stdin:
                self.gen.stdin.close()
            self.gen.wait(timeout=5)
        except Exception:
            try:
                self.gen.kill()
            except Exception:
                pass
        super().stop(message, state)
