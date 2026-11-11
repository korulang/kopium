#!/usr/bin/env python3
"""Framing ablation: does the [tN]-in-UserMessage render degrade reasoning
vs tau2's native ToolMessage framing? Same model, same data, same question.

  A: assistant tool_calls -> ToolMessages (stock shape), neutral prompt
  B: wire text -> [tN] UserMessage lines (kopium shape), neutral prompt
  C: wire text -> [tN] UserMessage lines, REAL kopium system prompt

Run: /Users/larsde/src/tau2-bench/.venv/bin/python bench/probe_framing.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, "/Users/larsde/src/tau2-bench/src")

from tau2.utils.llm_utils import generate
from tau2.data_model.message import (
    AssistantMessage, SystemMessage, ToolCall, ToolMessage, UserMessage,
)

from model_guard import guard_llm

MODEL = guard_llm("unset/no-default-model")
LLM_ARGS = {"timeout": 180, "reasoning_effort": "none"}

# The real reservation payloads from task 19 runs.
RES = {
    "Z7GOZK": {"reservation_id": "Z7GOZK", "user_id": "olivia_gonzalez_2305",
               "origin": "EWR", "destination": "IAH", "flight_type": "round_trip",
               "cabin": "basic_economy",
               "flights": [{"flight_number": "HAT188", "origin": "EWR", "destination": "IAH", "date": "2024-05-28", "price": 52},
                            {"flight_number": "HAT207", "origin": "IAH", "destination": "EWR", "date": "2024-05-28", "price": 87}],
               "passengers": [{"first_name": "Olivia", "last_name": "Gonzalez", "dob": "1988-06-13"}],
               "payment_history": [{"payment_id": "gift_card_2200803", "amount": 169}],
               "created_at": "2024-05-13T19:41:32", "total_baggages": 0, "nonfree_baggages": 0,
               "insurance": "yes", "status": None},
    "K67C4W": {"reservation_id": "K67C4W", "user_id": "olivia_gonzalez_2305",
               "origin": "LAS", "destination": "MCO", "flight_type": "one_way", "cabin": "economy",
               "flights": [{"flight_number": "HAT137", "origin": "LAS", "destination": "MCO", "date": "2024-05-17", "price": 114}],
               "passengers": [{"first_name": "Olivia", "last_name": "Gonzalez", "dob": "1988-06-13"},
                               {"first_name": "Mei", "last_name": "Johansson", "dob": "1981-09-25"},
                               {"first_name": "Yara", "last_name": "Lopez", "dob": "1975-09-15"}],
               "payment_history": [{"payment_id": "credit_card_9969263", "amount": 342}],
               "created_at": "2024-05-11T06:28:05", "total_baggages": 1, "nonfree_baggages": 0,
               "insurance": "no", "status": None},
    "THY2DG": {"reservation_id": "THY2DG", "user_id": "olivia_gonzalez_2305",
               "origin": "MSP", "destination": "ORD", "flight_type": "one_way", "cabin": "economy",
               "flights": [{"flight_number": "HAT248", "origin": "MSP", "destination": "DTW", "date": "2024-05-26", "price": 160},
                            {"flight_number": "HAT119", "origin": "DTW", "destination": "ORD", "date": "2024-05-26", "price": 178}],
               "passengers": [{"first_name": "Yara", "last_name": "Martin", "dob": "1950-01-15"}],
               "payment_history": [{"payment_id": "credit_card_9969263", "amount": 338}],
               "created_at": "2024-05-03T23:15:42", "total_baggages": 1, "nonfree_baggages": 0,
               "insurance": "no", "status": None},
}

NEUTRAL_SYS = ("You are a customer service agent for an airline. You help "
               "users look up and manage their flight reservations.")

USER_REQ = ("Hi, I need help with my reservation — a trip to Texas. My user "
            "ID is olivia_gonzalez_2305.")

QUESTION = ("I keep telling you — the Texas trip's return flight leaves Texas "
            "for Newark (EWR) on May 28th around 3pm. Looking at all three of "
            "my reservations, which reservation ID is the Texas trip?")

WIRE_CALLS = ('get-reservation-details(reservation_id: "Z7GOZK")\n'
              'get-reservation-details(reservation_id: "K67C4W")\n'
              'get-reservation-details(reservation_id: "THY2DG")')


def arm_a(sys_prompt):
    return [
        SystemMessage(role="system", content=sys_prompt),
        UserMessage(role="user", content=USER_REQ),
        AssistantMessage(role="assistant", content=None, tool_calls=[
            ToolCall(id=f"c_{k}", name="get_reservation_details",
                     arguments={"reservation_id": k}) for k in RES]),
        *[ToolMessage(id=f"c_{k}", role="tool",
                      content=json.dumps(v), requestor="assistant")
          for k, v in RES.items()],
        UserMessage(role="user", content=QUESTION),
    ]


def arm_b(sys_prompt):
    tn_lines = "\n".join(f"[t{i+1}] {json.dumps(v)}"
                         for i, (k, v) in enumerate(RES.items()))
    return [
        SystemMessage(role="system", content=sys_prompt),
        UserMessage(role="user", content=USER_REQ),
        AssistantMessage(role="assistant", content=WIRE_CALLS, tool_calls=None),
        UserMessage(role="user", content=tn_lines),
        UserMessage(role="user", content=QUESTION),
    ]


def main():
    kopium_sys = ""
    try:
        from kopium_agent import KopiumAgent
        a = KopiumAgent(tools=[], domain_policy="", domain="airline",
                        gate_binary=Path(__file__).parent / "airline-gate-binary")
        kopium_sys = a._system_prompt()
    except Exception as e:
        print(f"(could not build kopium system prompt: {e})", file=sys.stderr)

    arms = {"A(stock framing)": arm_a(NEUTRAL_SYS),
            "B([tN] neutral)": arm_b(NEUTRAL_SYS)}
    if kopium_sys:
        arms["C([tN]+kopium prompt)"] = arm_b(kopium_sys)

    for label, msgs in arms.items():
        wins = 0
        answers = []
        for i in range(3):
            try:
                r = generate(model=MODEL, messages=msgs, **LLM_ARGS)
            except Exception as e:
                answers.append(f"<error {e}>")
                continue
            text = r.content or ""
            answers.append(text.replace("\n", " ")[:140])
            if "Z7GOZK" in text:
                wins += 1
        print(f"{label}: {wins}/3 named Z7GOZK")
        for a in answers:
            print(f"    {a}")


if __name__ == "__main__":
    main()
