#!/usr/bin/env python3
"""LocalLladaAgent — the mock-domain agent whose model is LLaDA2.2-mini
running on this machine, warm-started by an n-gram draft.

Same contract as KopiumAgent (tau2 marshal) but the generation path is
local: a persistent gen_server.py subprocess (n-grams venv, MLX weights
resident) replaces the OpenRouter call, and a persistent GateSession on
mock-gate-binary replaces the per-line subprocess. The gate remains the
only legality oracle; Python still holds no judgment about the vocabulary.

Wire turn -> tau2 message mapping (tau2 forbids content+tool_calls on one
message — a mixed wire turn emits tool_calls now and its say text is held
for the next content-only message):
  say(text:)                -> AssistantMessage text (user sees it)
  <tool>(args) OK           -> ToolCall(<tau name>, args from gate echo)
  REJECT / HALT / ERROR     -> verdict text observed back, regenerate
                               (bounded); never reaches the user
  vocabulary()/grammar()/bind() -> observation only, turn continues
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
from gate_session import GateSession  # noqa: E402

NGRAMS = Path("/Users/larsde/src/n-grams")
GEN_SERVER = NGRAMS / "gen_server.py"
NGRAM_VENV_PY = NGRAMS / ".venv" / "bin" / "python"

_KORU_TO_TAU = {
    "create-task": "create_task",
    "get-users": "get_users",
    "update-task-status": "update_task_status",
    "transfer-to-human-agents": "transfer_to_human_agents",
}
_HOST_VERBS = {"vocabulary", "grammar", "bind", "abandon"}

# One assistant turn the model imitates — mock-scope analogue of
# tau_wire:seed-text (which only knows airline/db shapes). Arm bindings and
# a chain, ending in say — the shape every happy path takes.
SEED_WIRE = (
    'get-users() | ok us |\n'
    'say(text: "Hello! I can help you create and update tasks. What do you need?")'
)

_STEP_RE = re.compile(r"^step (\d+)/(\d+) (\w+):\s*(.*?)\s*$")
_BOUND_RE = re.compile(r"\s+bound:\s*(\S+)\s*$")
_INV_RE = re.compile(r"([A-Za-z][\w-]*)\s*\(")


class LocalAgentState:
    """tau2 messages + the model-facing wire transcript."""

    def __init__(self, system_messages: list[SystemMessage], messages: list[Message]):
        self.system_messages = system_messages
        self.messages = messages
        self.transcript: list[dict] = []  # {"role","content"} for gen_server
        self.pending_say: Optional[str] = None
        self.call_seq = 0
        self.bound_by_call: dict[str, str] = {}


class LocalLladaAgent(HalfDuplexAgent[LocalAgentState]):
    def __init__(
        self,
        tools: list[Tool],
        domain_policy: str,
        gate_binary: Path,
        *,
        arm: str = "warm",
        draft: Optional[str] = "ngrams/llada22-o4-koru-k.pkl",
        draft_temperature: float = 1.0,
        draft_frac: float = 1.0,
        steps: int = 16,
        max_tokens: int = 192,
        temperature: float = 0.0,
        max_internal: int = 8,
        seed: int = 0,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        self.gate = GateSession(Path(gate_binary))
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
        self.draft_temperature = draft_temperature
        self.draft_frac = draft_frac
        self.steps = steps
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.max_internal = max_internal
        self.seed = seed
        self.call_count = 0
        self.gen_calls = 0
        self.rejections = 0
        self.system_text = ""
        self._verbs: set[str] = set()
        self._abandoned = False
        self.trace: list[str] = []

    # ------------------------------------------------------------- plumbing
    def _gen(self, messages: list[dict]) -> dict:
        req = {
            "messages": messages,
            "max_tokens": self.max_tokens,
            "steps": self.steps,
            "temperature": self.temperature,
            "arm": self.arm,
            "seed": self.seed + self.gen_calls,
        }
        if self.draft:
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
        return resp

    @staticmethod
    def _clean_wire(text: str) -> str:
        wire = text.strip()
        if wire.startswith("```"):
            wire = wire.split("\n", 1)[-1] if "\n" in wire else ""
            wire = wire.rsplit("```", 1)[0]
        # rstrip each line (keep leading indent — arm blocks need it),
        # drop blank lines (a blank line terminates the gate's turn early)
        return "\n".join(ln.rstrip() for ln in wire.splitlines() if ln.strip())

    @staticmethod
    def _split_args(s: str) -> list[str]:
        parts, depth, cur, in_str, esc = [], 0, "", False, False
        for ch in s:
            if esc:
                cur += ch
                esc = False
            elif ch == "\\" and in_str:
                cur += ch
                esc = True
            elif ch == '"':
                in_str = not in_str
                cur += ch
            elif ch in "([{" and not in_str:
                depth += 1
                cur += ch
            elif ch in ")]}":
                depth -= 1
                cur += ch
            elif ch == "," and depth == 0 and not in_str:
                parts.append(cur)
                cur = ""
            else:
                cur += ch
        if cur.strip():
            parts.append(cur)
        return parts

    @staticmethod
    def _unquote(raw: str):
        raw = raw.strip()
        if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
            return raw[1:-1].replace('\\"', '"').replace("\\\\", "\\")
        return raw

    def _vocab_verbs(self) -> set[str]:
        """Closed verb set from gate.vocabulary() — `pub tor name {`
        declarations plus bare `name(...)` host-verb lines."""
        verbs = set()
        for ln in self.gate.vocabulary().splitlines():
            m = re.match(r"pub tor ([\w-]+)", ln) or re.match(r"([\w-]+)\(", ln)
            if m:
                verbs.add(m.group(1))
        return verbs

    @staticmethod
    def _balanced_args(wire: str, open_pos: int):
        """wire[open_pos] == '(' -> (inner, index_after_close). Quote-aware."""
        depth, in_str, esc = 0, False, False
        for i in range(open_pos, len(wire)):
            ch = wire[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
                continue
            if ch == '"':
                in_str = True
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return wire[open_pos + 1 : i], i + 1
        return wire[open_pos + 1 :], len(wire)

    def _extract_invocations(self, wire: str):
        """Every `verb(args)` in wire order — chains (`a | ok v |> say()`),
        multi-line turns, and indented arm blocks all reduce to this.
        Matches inside quoted strings are skipped. Returns [(verb, args)]."""
        invs = []
        i, n = 0, len(wire)
        while i < n:
            if wire[i] == '"':
                j = i + 1
                while j < n:
                    if wire[j] == "\\":
                        j += 2
                        continue
                    if wire[j] == '"':
                        break
                    j += 1
                i = j + 1
                continue
            m = _INV_RE.match(wire, i)
            if m:
                verb = m.group(1)
                argstr, end = self._balanced_args(wire, m.end() - 1)
                if verb in self._verbs:
                    args = {}
                    for pair in self._split_args(argstr):
                        name, sep, raw = pair.partition(":")
                        name = name.strip()
                        if sep and name:
                            args[name] = self._unquote(raw)
                    invs.append((verb, args))
                i = end
                continue
            i += 1
        return invs

    @staticmethod
    def _payload_args(payload: str) -> dict:
        """{branch,value} wrapper or bare echo JSON -> args dict."""
        try:
            outer = json.loads(payload)
        except (json.JSONDecodeError, TypeError):
            return {}
        if not isinstance(outer, dict) or "value" not in outer:
            return outer if isinstance(outer, dict) else {}
        inner = outer["value"]
        if isinstance(inner, str):
            try:
                inner = json.loads(inner)
            except json.JSONDecodeError:
                return {}
        return inner if isinstance(inner, dict) else {}

    # ------------------------------------------------------------- the gate
    def _observe(self, state: LocalAgentState, role: str, text: str) -> None:
        state.transcript.append({"role": role, "content": text})

    def _result_observe(
        self, state: LocalAgentState, verb: str, bound: str, payload: str
    ) -> None:
        args = self._payload_args(payload)
        inner = json.dumps(args, separators=(",", ":")) if args else payload
        self._observe(state, "user", f'result: {inner} bound: {bound or "?"}')

    def _bound_calls(self, state: LocalAgentState, invs, last_bound: str):
        """Assign durable rN names backward from the turn's last dispatch —
        every invocation consumes one rN in order (host verbs included)."""
        n = len(invs)
        bnum = (
            int(last_bound[1:])
            if last_bound.startswith("r") and last_bound[1:].isdigit()
            else 0
        )
        return [
            (v, a, f"r{bnum - n + 1 + i}" if bnum else "")
            for i, (v, a) in enumerate(invs)
        ]

    def _emit_from_calls(self, state: LocalAgentState, calls):
        """calls = [(verb, args, bound)] -> (say_texts, [ToolCall])."""
        say_texts: list[str] = []
        tool_calls: list[ToolCall] = []
        for verb, args, bound in calls:
            if verb == "say":
                say_texts.append(str(args.get("text", "")))
            elif verb == "abandon":
                say_texts.append(str(args.get("reason", "")))
            elif verb in _HOST_VERBS:
                continue
            elif verb in _KORU_TO_TAU:
                state.call_seq += 1
                cid = f"k{state.call_seq}"
                clean = {k: v for k, v in args.items() if v not in ("", None)}
                tc = ToolCall(id=cid, name=_KORU_TO_TAU[verb], arguments=clean)
                tool_calls.append(tc)
                if bound:
                    state.bound_by_call[cid] = bound
            else:
                say_texts.append(f"[gate-ok unmapped verb: {verb}]")
        return say_texts, tool_calls

    def _turn_outcome(self, wire: str, state: LocalAgentState):
        """-> ('emit', say_texts, tool_calls) | ('retry', observation)."""
        status, detail = self.gate.send(wire)
        self.trace.append(f"  [wire ] {wire!r}")
        self.trace.append(f"  [gate ] {status} {detail[:300]}")
        invs = self._extract_invocations(wire)

        if status == "OK":
            verb, bound, payload = GateSession.parse_ok(detail)
            self._result_observe(state, verb, bound, payload)
            # A chained turn returns ONE OK: first verb's name, LAST
            # dispatch's value+bound. Args come from source; rN assigned
            # backward across all invocations.
            calls = self._bound_calls(state, invs, bound)
            return ("emit",) + self._emit_from_calls(state, calls)

        if status == "STEPS":
            step_lines = [ln for ln in detail.splitlines() if ln.strip()]
            parsed = []
            for ln in step_lines:
                m = _STEP_RE.match(ln)
                if not m:
                    parsed.append(None)
                    continue
                _, _, st, rest = m.groups()
                bm = _BOUND_RE.search(rest)
                bound = bm.group(1) if bm else ""
                payload = rest[: bm.start()] if bm else rest
                parsed.append((st, payload, bound))
            if parsed and all(p and p[0] == "result" for p in parsed):
                for p in parsed:
                    self._observe(
                        state, "user",
                        f"result: {p[1]} bound: {p[2] or '?'}",
                    )
                last_bound = parsed[-1][2] if parsed else ""
                calls = self._bound_calls(state, invs, last_bound)
                return ("emit",) + self._emit_from_calls(state, calls)
            obs = "\n".join(step_lines)
            self._observe(state, "user", obs)
            self.rejections += 1
            return ("retry", obs)

        if status == "DEFINED":
            self._observe(state, "user", f"defined: {detail}")
            return ("retry", f"defined: {detail}")

        if status == "HALT":
            # abandon() ends the gate session with HALT, not OK — surface
            # the reason as the final say instead of retrying a dead end.
            for v, a in invs:
                if v == "abandon":
                    reason = str(a.get("reason", ""))
                    self._observe(state, "user", f"session ended: {reason}")
                    self._abandoned = True
                    return ("emit", [reason], [])
            obs = f"unhandled-branch: {detail}"
        elif status == "REJECT":
            obs = detail
        else:
            obs = f"{status.lower()}: {detail}"
        self._observe(state, "user", obs)
        self.rejections += 1
        return ("retry", obs)

    # ------------------------------------------------------------- the turn
    def get_init_state(self, message_history=None):
        grammar = self.gate.grammar()
        self._verbs = self._vocab_verbs()
        policy_block = (
            "\n\nDOMAIN POLICY — the rules every action must satisfy. Judge "
            "each request against these conditions, reading them against the "
            "records you fetch.\n\n" + self.domain_policy
        )
        self.system_text = grammar + policy_block
        state = LocalAgentState(
            [SystemMessage(role="system", content=self.system_text)],
            list(message_history or []),
        )
        state.transcript.append({"role": "assistant", "content": SEED_WIRE})
        return state

    def _ingest(self, message: Message, state: LocalAgentState) -> None:
        if isinstance(message, UserMessage):
            self._observe(state, "user", f"user: {message.content}")
        elif isinstance(message, MultiToolMessage):
            for tm in message.tool_messages:
                self._ingest_tool(tm, state)
        elif isinstance(message, ToolMessage):
            self._ingest_tool(message, state)

    def _ingest_tool(self, tm: ToolMessage, state: LocalAgentState) -> None:
        bound = state.bound_by_call.get(tm.id or "", "?")
        content = tm.content or ""
        branch = "error" if tm.error else ""
        text = (
            f'result: {{"branch":"{branch}","value":{json.dumps(content)}}} '
            f"bound: {bound}"
        )
        self._observe(state, "user", text)
        self.trace.append(f"  [tool ] {tm.id} -> {content[:200]}")

    def _msgs(self, state: LocalAgentState) -> list[dict]:
        return [{"role": "system", "content": self.system_text}] + state.transcript

    def generate_next_message(self, message, state: LocalAgentState):
        self.call_count += 1
        self._ingest(message, state)

        if state.pending_say is not None:
            text = state.pending_say
            state.pending_say = None
            out = AssistantMessage.text(text)
            state.messages.append(out)
            return out, state

        # Gate session ended via abandon() — keep the sim alive with a
        # static close; no generation, no gate.
        if self._abandoned:
            out = AssistantMessage.text("[session ended]")
            state.messages.append(out)
            return out, state

        for _ in range(self.max_internal):
            resp = self._gen(self._msgs(state))
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
                continue

            self._observe(state, "assistant", wire)

            outcome = self._turn_outcome(wire, state)
            if outcome[0] == "retry":
                continue
            _, say_texts, tool_calls = outcome
            say_text = "\n\n".join(t for t in say_texts if t)
            if tool_calls:
                if say_text:
                    state.pending_say = say_text
                out = AssistantMessage.text("", tool_calls=tool_calls)
            elif say_text:
                out = AssistantMessage.text(say_text)
            else:
                self._observe(
                    state, "user",
                    "that reply reached nobody — `say(text: ...)` reaches the "
                    "user, `verb(field: ...)` calls",
                )
                continue
            state.messages.append(out)
            return out, state

        raise RuntimeError(
            f"agent wire loop exhausted ({self.max_internal} internal turns)"
        )

    def stop(self, message=None, state=None):
        try:
            self.gate.close()
        except Exception:
            pass
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
