#!/usr/bin/env python3
"""
Run one airline task against the Koru gate.

  python3 bench/run_airline.py [task_id]

When task_id is omitted, runs task 0 — the showcase: the user asks to cancel a
reservation that is past the 24-hour policy window; the correct trajectory
performs NO tool call (actions=[]) and refuses via say(). The DB must remain
byte-identical to gold, which is exactly what the register block's `say`
achiever: the only verbs that mutate the DB (cancel-reservation) sit in the
block so the model CAN call them — and must choose not to.
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from kopium_agent import KopiumAgent, AIRLINE_CONFIG

HERE = Path(__file__).parent
GATE = HERE / "airline-gate-binary"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 else "0"
    llm = "openrouter/anthropic/claude-haiku-4.5"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]

    if not GATE.exists():
        sys.exit(f"airline gate missing: build it in {HERE} with koruc airline-gate.k")

    env = build_environment("airline")
    tasks = get_tasks("airline", task_ids=[task_id])
    if not tasks:
        sys.exit(f"no airline task {task_id!r}")
    task = tasks[0]

    inst = getattr(task.user_scenario, "instructions", "") or ""
    if hasattr(inst, "model_dump"):
        inst = inst.model_dump()
    if isinstance(inst, (list, tuple)):
        inst = inst[0]
    crit = task.evaluation_criteria.model_dump()
    actions = [a["name"] for a in (crit.get("actions") or [])]

    print(f"task      : {task.id}")
    print(f"golden    : {actions or '(no tool calls - the refusal)'}")
    print(f"asked     : {str(inst)[:140]}")
    print()

    agent = KopiumAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        domain="airline", gate_binary=GATE,
        llm=llm,
    )
    user = build_user("user_simulator", env, task, llm=llm)
    orch = Orchestrator(
        domain="airline",
        agent=agent,
        user=user,
        environment=env,
        task=task,
        max_steps=40,
        max_errors=5,
        seed=42,
    )
    res = run_simulation(orch, evaluation_type=EvaluationType.ALL)

    print("=" * 60)
    print(f"reward     : {res.reward_info.reward}")
    print(f"db_check   : {res.reward_info.db_check}")
    print(f"comm_checks: {getattr(res.reward_info, 'communicate_checks', None)}")
    print(f"breakdown  : {getattr(res.reward_info, 'reward_breakdown', None)}")
    print(f"agent calls: {agent.call_count}")
    print()
    print("trajectory:")
    for i, m in enumerate(res.messages):
        tcs = getattr(m, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                print(f"  [{i}] TOOL {tc.name}({tc.arguments})")
            continue
        c = (str(m.content) or "")[:160]
        print(f"  [{i}] {type(m).__name__}: {c}")


if __name__ == "__main__":
    main()