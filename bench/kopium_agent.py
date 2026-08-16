#!/usr/bin/env python3
"""
KOPIUM agent for tau3-bench — the agent uses ONLY Koru as its tool surface.

Every decision the model makes is ONE line of Koru. Nothing about what may or
may not be called is typed in this file:

  - The VOCABULARY given to the model is rendered by the interpreter from the
    register block (mock-vocab-binary / airline-vocab-binary, which call
    std/runtime:scope-vocabulary). The prompt is built from that output at
    construction. There is no duplicate tool list here to drift.
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


def _run_bin(bin_path: Path, stdin: str) -> str:
    proc = subprocess.run(
        [str(bin_path)], input=stdin.encode(), capture_output=True, timeout=15
    )
    return proc.stdout.decode(errors="replace").strip()


@dataclass(frozen=True)
class DomainConfig:
    """One benchmark domain: gate + vocab binaries, name map, policy rules."""

    name: str
    gate_binary: Path
    vocab_binary: Path
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
    vocab_binary=Path(__file__).parent / "mock-vocab-binary",
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
    vocab_binary=Path(__file__).parent / "airline-vocab-binary",
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
                vocab_binary=self.cfg.vocab_binary,
                koru_to_tau=self.cfg.koru_to_tau,
                extra_rules=self.cfg.extra_rules,
            )
        self.llm = llm
        self.llm_args = llm_args or {}
        self.call_count = 0

    # ------------------------------------------------------- the vocabulary
    def _vocabulary(self) -> str:
        """The register block's own render — the ONLY source of what the model
        may call. Empty/error => empty list; the gate still enforces reality,
        so a broken vocab render can only make the model guess, never let an
        illegal call through."""
        out = _run_bin(self.cfg.vocab_binary, "x\n")
        if out.startswith("ERROR"):
            return ""
        return out

    def get_init_state(
        self, message_history: Optional[list[Message]] = None
    ) -> KopiumAgentState:
        vocab = self._vocabulary()
        vocab_lines = "\n".join(f"- {v}" for v in vocab.splitlines() if v)
        rules = "\n".join(f"- {r}" for r in self.cfg.extra_rules)
        literal_rules = (
            "- If you cannot or must not do what the user asks, call "
            "say(text: ...) with the honest reason, and call NO tool."
        )
        system_prompt = (
            f"You are a customer service agent. Every reply is EXACTLY ONE "
            f"invocation in the Koru vocabulary below — nothing else, no prose, "
            f"no markdown, no leading ~. Arguments are name: \"value\" pairs.\n\n"
            f"## Domain policy\n{self.domain_policy}\n\n"
            f"## Your vocabulary (exactly these lines, rendered from the "
            f"register block)\n{vocab_lines}\n\n"
            f"## Rules\n{rules}\n{literal_rules}"
        )
        return KopiumAgentState(
            system_messages=[SystemMessage(role="system", content=system_prompt)],
            messages=list(message_history) if message_history else [],
        )

    # -------------------------------------------------------------- the gate
    def _gate(self, source: str) -> tuple[str, str]:
        """Run one Koru line through the gate. Returns (status, detail)."""
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
        #    only "tool schema" the model sees is the register block render.
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

        # 2. The Koru gate decides. A REJECT means the line was not Koru or not
        #    in the vocabulary — the interpreter refusing exactly as designed.
        #    But a drift is not a customer-facing event: it is an internal
        #    mistake the model should get ONE chance to fix before we burn the
        #    turn on a spoken refusal. Retry once with the rejection as the
        #    instruction, because in-vocabulary drift is the one failure mode
        #    the register block can only detect, not prevent.
        status, detail = self._gate(reply)
        if status != "OK":
            state.messages.append(
                UserMessage.text(
                    f"[internal] Your last reply was not accepted: {detail}. "
                    f"Reply with EXACTLY ONE invocation from the vocabulary."
                )
            )
            response = generate(
                model=self.llm,
                messages=state.system_messages + state.messages,
                **self.llm_args,
            )
            reply = (response.content or "").strip()
            if reply.startswith("```"):
                reply = re.sub(r"```(?:[a-z]*)\n?", "", reply).strip()
                reply = reply.split("```")[0].strip()
            if not reply:
                reply = 'say(text: "I need a moment.")'
            status, detail = self._gate(reply)

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
                    "", tool_calls=[ToolCall(name=tau_name, arguments=args)]
                )
        else:
            # Second rejection: the model cannot find the vocabulary. Say so —
            # tau3 scores refusals as correct when the policy demands one, and
            # a breakdown that says nothing is worse than an honest one.
            out = AssistantMessage.text(f"I cannot do that: {detail}")

        state.messages.append(out)
        return out, state