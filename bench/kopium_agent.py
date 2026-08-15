#!/usr/bin/env python3
"""
KOPIUM agent for tau3-bench — the mock-domain pilot.

The agent's ONLY tool surface is a line of Koru vetted by the interpreter:
every invocation the model produces goes through the mock-gate binary, which
dispatches it against the `register` block from mock_tools.kz. A verb not in
the block comes back REJECT from the LANGUAGE. Only an OK line becomes a tau3
ToolCall; everything else is a spoken refusal/fix-up.

The two spelling worlds meet here in exactly two translations:
  - tau3 tool names (create_task)  <->  Koru tor names (create-task)
  - a JSON argument dict           <->  the name: "value" pairs in a Koru line

The vocabulary itself — and the refusal — come from mock_tools.kz. Nothing in
this file decides what the agent may or may not call. Notably, `generate()` is
called with NO `tools=`: the model is handed the vocabulary as prose and must
answer in one line of Koru, exactly as a session in the notes agent does.

Usage (from the harness examples' manual-build path):
    agent = KopiumAgent(tools=env.get_tools(), domain_policy=env.get_policy(), ...)
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Optional

from tau2.agent.base_agent import HalfDuplexAgent
from tau2.data_model.message import (
    AssistantMessage,
    Message,
    SystemMessage,
    UserMessage,
    ToolCall,
)
from tau2.environment.toolkit import Tool
from tau2.utils.llm_utils import generate

# Koru tor name -> tau3 tool name (two spellings of the same verb)
_KORU_TO_TAU = {
    "create-task": "create_task",
    "get-users": "get_users",
    "update-task-status": "update_task_status",
    "transfer-to-human-agents": "transfer_to_human_agents",
}
_TAU_TO_KORU = {v: k for k, v in _KORU_TO_TAU.items()}

# The Koru vocabulary line list, exactly as the model must see it. Draws on the
# register block's events; mirrored here for the model prompt (the gate
# enforces the real thing — a drift here only makes the model guess wrong, it
# can never make an illegal call legal).
_VOCAB = [
    "create-task(user_id: string, title: string, description: string)",
    "get-users()",
    "update-task-status(task_id: string, status: string)",
    "transfer-to-human-agents(summary: string)",
    "say(text: string)",
]


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
        gate_binary: Path,
        llm: str = "openai/gpt-4.1-mini",
        llm_args: Optional[dict] = None,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        self.gate_binary = Path(gate_binary)
        self.llm = llm
        self.llm_args = llm_args or {}
        self.call_count = 0

    # ------------------------------------------------------------------ state
    def get_init_state(
        self, message_history: Optional[list[Message]] = None
    ) -> KopiumAgentState:
        vocab_lines = "\n".join(f"- {v}" for v in _VOCAB)
        system_prompt = (
            f"You are a customer service agent. Every reply is EXACTLY ONE "
            f"invocation in the Koru vocabulary below — nothing else, no prose, "
            f"no markdown, no leading ~.\n\n"
            f"## Domain policy\n{self.domain_policy}\n\n"
            f"## Your vocabulary (exactly these lines, nothing else)\n{vocab_lines}\n\n"
            f"## Rules\n"
            f"- Check what has already been done before acting. When a task is "
            f"already created or resolved in the tool results, do NOT call the "
            f"tool again — confirm to the user via say(text: ...).\n"
            f"- Never repeat a tool call that already succeeded with the same "
            f"purpose.\n"
            f"- Only pass arguments the user actually gave you. Never invent an "
            f"optional argument (like a description the user never mentioned)."
        )
        return KopiumAgentState(
            system_messages=[SystemMessage(role="system", content=system_prompt)],
            messages=list(message_history) if message_history else [],
        )

    # -------------------------------------------------------------- the gate
    def _gate(self, source: str) -> tuple[str, str]:
        """Run one Koru line through mock-gate. Returns (status, detail)."""
        try:
            proc = subprocess.run(
                [str(self.gate_binary)],
                input=source.encode(),
                capture_output=True,
                timeout=10,
            )
        except subprocess.TimeoutExpired:
            return "ERROR", "gate timed out"
        stdout = proc.stdout.decode(errors="replace").strip()
        if not stdout:
            return "ERROR", "gate produced no output"
        # Lines: "OK <event>" | "REJECT <detail>" | "ERROR <detail>"
        status, _, detail = stdout.partition(" ")
        return status, detail.strip()

    @staticmethod
    def _parse_args(source: str) -> dict[str, str]:
        """Parse `name(arg: "v", arg2: "w")` into {arg: v, ...}.

        Only called on a line the gate already returned OK for. The quotes are
        the Koru string convention; unquoted values are passed through.
        """
        m = re.fullmatch(r"\s*[^(\s]+\s*\((.*)\)\s*", source, re.DOTALL)
        if not m:
            return {}
        args: dict[str, str] = {}
        for pair in _split_top_level(m.group(1)):
            name, _, raw = pair.partition(":")
            name = name.strip()
            raw = raw.strip()
            if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
                raw = raw[1:-1]
            args[name] = raw
        return args

    # ------------------------------------------------------------ the loop
    def generate_next_message(
        self, message: UserMessage, state: KopiumAgentState
    ) -> tuple[AssistantMessage, KopiumAgentState]:
        self.call_count += 1

        # tau3 alternates user turns with tool results. A ToolMessage is DB
        # output, not something the user said: label it the way the wire's
        # [tool result] convention does, so the model can tell a customer's
        # words from the environment's answer.
        from tau2.data_model.message import ToolMessage

        if isinstance(message, ToolMessage):
            shown = f"[tool result] {message.content}"
            state.messages.append(UserMessage.text(shown))
        else:
            state.messages.append(message)

        # 1. Ask the model for ONE line of Koru. No tools are offered — the
        #    only "tool schema" the model sees is the vocabulary above.
        response = generate(
            model=self.llm,
            messages=state.system_messages + state.messages,
            **self.llm_args,
        )
        reply = (response.content or "").strip()

        # Strip incidental fences the model volunteers.
        if reply.startswith("```"):
            reply = re.sub(r"```(?:[a-z]*)\n?", "", reply).strip()
            reply = reply.split("```")[0].strip()
        if not reply:
            reply = 'say(text: "I need a moment.")'

        # 2. The Koru gate decides.
        status, detail = self._gate(reply)
        if status == "OK":
            koru_name = detail
            tau_name = _KORU_TO_TAU.get(koru_name, koru_name)
            if tau_name == "say":
                # say(...) is the voice channel: a plain-text assistant message
                args = self._parse_args(reply)
                text = args.get("text", "")
                out = AssistantMessage.text(text)
            else:
                args = {k: v for k, v in self._parse_args(reply).items() if v != ""}
                out = AssistantMessage.text("", tool_calls=[ToolCall(name=tau_name, arguments=args)])
        else:
            # REJECT or ERROR: the interpreter refused. The agent says so, as
            # the refusal surface — tau3 scores refusals as correct when the
            # policy demands one.
            out = AssistantMessage.text(f"I cannot do that: {detail}")

        state.messages.append(out)
        return out, state


def _split_top_level(s: str) -> list[str]:
    """Split on commas ignoring quoted commas (arg values are simple here)."""
    parts: list[str] = []
    depth = 0
    cur = ""
    in_str = False
    for ch in s:
        if ch == '"':
            in_str = not in_str
            cur += ch
        elif ch in "([{" and not in_str:
            depth += 1
            cur += ch
        elif ch in ")]}" and not in_str:
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