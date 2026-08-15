#!/usr/bin/env python3
"""
KOPIUM agent for tau3-bench.

The agent's ONLY tool surface is a line of Koru vetted by the interpreter:
every invocation the model produces goes through a gate binary, which
dispatches it against the `register` block in the domain's *_tools.kz. A verb
not in the block comes back REJECT from the LANGUAGE. Only an OK line becomes
a tau3 ToolCall; everything else is a spoken refusal/fix-up.

The two spelling worlds meet here in exactly two translations:
  - tau3 tool names (create_task)  <->  Koru tor names (create-task)
  - a JSON argument dict           <->  the name: "value" pairs in a Koru line
    (structured tau3 args ride inside Koru string params as JSON)

The vocabulary itself — and the refusal — come from the register blocks
(mock_tools.kz, airline_tools.kz). Nothing in this file decides what the agent
may or may not call. Notably, `generate()` is called with NO `tools=`: the
model is handed the vocabulary as prose and must answer in one line of Koru.

Usage:
    agent = KopiumAgent(tools=..., domain_policy=..., gate_binary=...,
                        koru_to_tau={...}, vocab=[...], llm=...)
"""

from __future__ import annotations

import re
import subprocess
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
)
from tau2.environment.toolkit import Tool
from tau2.utils.llm_utils import generate


@dataclass(frozen=True)
class DomainConfig:
    """One benchmark domain: its gate binary, tool-name mapping, vocabulary."""

    name: str
    gate_binary: Path
    # Koru tor name -> tau3 tool name. Omitted verbs (like `say`, the voice
    # channel) pass through unchanged.
    koru_to_tau: dict[str, str] = field(default_factory=dict)
    # The vocabulary lines exactly as rendered from the register block, shown
    # to the model. The gate enforces the real thing; drift here only makes
    # the model guess wrong, never makes an illegal call legal.
    vocab: list[str] = field(default_factory=list)
    # Extra rules appended to the system prompt, domain-specific.
    extra_rules: list[str] = field(default_factory=list)

    @property
    def tau_to_koru(self) -> dict[str, str]:
        return {v: k for k, v in self.koru_to_tau.items()}


# ---------------------------------------------------------------------------
# The domains, one config each. The register blocks are the authority; these
# mirror them for the model prompt and the tau3 spelling.
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
    vocab=[
        "create-task(user_id: string, title: string, description: string)",
        "get-users()",
        "update-task-status(task_id: string, status: string)",
        "transfer-to-human-agents(summary: string)",
        "say(text: string)",
    ],
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
    gate_binary=Path("/Users/larsde/src/kopium/bench/airline-gate"),
    koru_to_tau={
        "get-user-details": "get_user_details",
        "get-reservation-details": "get_reservation_details",
        "search-direct-flight": "search_direct_flight",
        "cancel-reservation": "cancel_reservation",
    },
    vocab=[
        "say(text: string)",
        "get-user-details(user_id: string)",
        "get-reservation-details(reservation_id: string)",
        "search-direct-flight(origin: string, destination: string, date: string)",
        "cancel-reservation(reservation_id: string)",
    ],
    extra_rules=[
        # The showcase rule, from the airline policy: the API does not check
        # cancellation rules — the AGENT must, before calling the API.
        "The cancellation API does NOT check whether cancellation is allowed. "
        "YOU must apply the policy before calling cancel-reservation. When the "
        "policy forbids it (more than 24 hours after booking, no insurance "
        "covering the reason, portion already flown), refuse via say(text: ...) "
        "and do NOT call cancel-reservation.",
        "Only pass arguments the user actually gave you.",
    ],
)

_CONFIGS = {"mock": MOCK_CONFIG, "airline": AIRLINE_CONFIG}

# `say` is the voice channel in every domain: a plain spoken message, never a
# tau3 write tool.
_SPOKEN = {"say"}


def get_config(name: str, gate_binary: Optional[Path] = None) -> DomainConfig:
    cfg = _CONFIGS[name]
    if gate_binary is not None:
        # Allow overriding the binary path at construction (the harness may
        # build it elsewhere).
        return DomainConfig(
            name=cfg.name,
            gate_binary=gate_binary,
            koru_to_tau=cfg.koru_to_tau,
            vocab=cfg.vocab,
            extra_rules=cfg.extra_rules,
        )
    return cfg


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
        domain: str = "mock",
        llm: str = "openrouter/anthropic/claude-haiku-4.5",
        llm_args: Optional[dict] = None,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        self.cfg = get_config(domain, gate_binary=gate_binary)
        self.koru_to_tau = self.cfg.koru_to_tau
        self.llm = llm
        self.llm_args = llm_args or {}
        self.call_count = 0

    def get_init_state(
        self, message_history: Optional[list[Message]] = None
    ) -> KopiumAgentState:
        vocab_lines = "\n".join(f"- {v}" for v in self.cfg.vocab)
        rules = "\n".join(f"- {r}" for r in self.cfg.extra_rules)
        literal_rules = (
            "- If you cannot or must not do what the user asks, call "
            "say(text: ...) with the honest reason, and call NO tool."
        )
        system_prompt = (
            f"You are a customer service agent. Every reply is EXACTLY ONE "
            f"invocation in the Koru vocabulary below — nothing else, no prose, "
            f"no markdown, no leading ~.\n\n"
            f"## Domain policy\n{self.domain_policy}\n\n"
            f"## Your vocabulary (exactly these lines, nothing else)\n{vocab_lines}\n\n"
            f"## Rules\n{rules}\n{literal_rules}"
        )
        return KopiumAgentState(
            system_messages=[SystemMessage(role="system", content=system_prompt)],
            messages=list(message_history) if message_history else [],
        )

    # -------------------------------------------------------------- the gate
    def _gate(self, source: str) -> tuple[str, str]:
        """Run one Koru line through the domain gate. Returns (status, detail)."""
        try:
            proc = subprocess.run(
                [str(self.cfg.gate_binary)],
                input=source.encode(),
                capture_output=True,
                timeout=15,
            )
        except subprocess.TimeoutExpired:
            return "ERROR", "gate timed out"
        stdout = proc.stdout.decode(errors="replace").strip()
        if not stdout:
            return "ERROR", "gate produced no output"
        status, _, detail = stdout.partition(" ")
        return status, detail.strip()

    @staticmethod
    def _parse_args(source: str) -> dict[str, str]:
        """Parse `name(arg: "v", arg2: "w")` into {arg: v, ...}.

        Only called on a line the gate already returned OK for. Structured
        args (lists/objects) ride inside string values as JSON and pass
        through untouched.
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
        # [tool result] convention does.
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
            if koru_name in _SPOKEN:
                args = self._parse_args(reply)
                text = args.get("text", "")
                out = AssistantMessage.text(text)
            else:
                tau_name = self.koru_to_tau.get(koru_name, koru_name)
                args = {k: v for k, v in self._parse_args(reply).items() if v != ""}
                out = AssistantMessage.text(
                    "", tool_calls=[ToolCall(name=tau_name, arguments=args)]
                )
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