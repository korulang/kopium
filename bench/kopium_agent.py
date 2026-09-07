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
import re
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
        self.llm_args = llm_args or {}
        self.call_count = 0
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
        if "A wire line is exactly one invocation" not in grammar:
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
            f"This is a STATE LOOP: each of your turns emits EXACTLY ONE Koru "
            f"invocation, the system runs it, and the outcome comes back as "
            f"`[tool result] ...`. Read the last result, decide the next single "
            f"verb, and repeat until the task is done.\n\n"
            f"## Koru (derived from this session's Bridge — 440_017)\n"
            f"{grammar}\n\n"
            f"## Happy path — chain reads first, then act\n"
            f"Multi-step tasks are done as a sequence of single-verb turns, "
            f"using each `[tool result]` to pick the next verb. Example "
            f"(cancellation):\n"
            f"  user: I need to cancel my reservation.\n"
            f"  you:   get-user-details(user_id: \"...\")\n"
            f"  you:   get-reservation-details(reservation_id: \"...\")\n"
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
        return self._ensure_session().send(source)

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
        # NO empty-reply fallback: an empty model reply is a real signal
        # (the model produced no invocation). Feed it to the gate, which
        # rejects it, and let the one-retry teaching path below recover it —
        # manufacturing an in-vocabulary "I need a moment." stall instead
        # would hide failure as progress and burn the turn.

        # 2. The Koru gate decides. A REJECT means the line was not Koru or not
        #    in the vocabulary — the interpreter refusing exactly as designed.
        #    But a drift is not a customer-facing event: it is an internal
        #    mistake the model should get ONE chance to fix before we burn the
        #    turn on a spoken refusal. Retry once with the rejection as the
        #    instruction, because in-vocabulary drift is the one failure mode
        #    the register block can only detect, not prevent.
        status, detail = self._gate(reply)
        if status == "DEFINED":
            self._refresh_vocab(state)
            out = AssistantMessage.text(f"defined {detail}")
            state.messages.append(out)
            return out, state
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
            status, detail = self._gate(reply)
            if status == "DEFINED":
                self._refresh_vocab(state)
                out = AssistantMessage.text(f"defined {detail}")
                state.messages.append(out)
                return out, state

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