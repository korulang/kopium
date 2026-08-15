#!/usr/bin/env python3
"""
Run the full mock-domain set against the Koru gate, one line per task.

  python3 bench/run_all_mock.py [--llm openrouter/anthropic/claude-haiku-4.5]

Prints a table: task, reward, agent calls, and the decisive tool call.
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from kopium_agent import KopiumAgent

HERE = Path(__file__).parent
GATE = HERE / "mock-gate-binary"


def main() -> None:
    llm = "openrouter/anthropic/claude-haiku-4.5"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]

    task_ids = [a for a in sys.argv[1:] if a != "--llm"]
    if not task_ids:
        task_ids = ["create_task_1", "update_task_1"]

    if not GATE.exists():
        sys.exit(f"gate binary missing: cd {HERE} && koruc mock-gate.k")

    print(f"model: {llm}")
    print(f"{'task':30s} {'reward':>6s} {'calls':>5s}  decisive call")
    print("-" * 78)

    for tid in task_ids:
        env = build_environment("mock")
        tasks = get_tasks("mock", task_ids=[tid])
        if not tasks:
            print(f"{tid:30s}  NO SUCH TASK")
            continue
        task = tasks[0]
        agent = KopiumAgent(
            tools=env.get_tools(),
            domain_policy=env.get_policy(),
            domain="mock", gate_binary=GATE,
            llm=llm,
        )
        user = build_user("user_simulator", env, task, llm=llm)
        orch = Orchestrator(
            domain="mock",
            agent=agent,
            user=user,
            environment=env,
            task=task,
            max_steps=20,
            max_errors=5,
            seed=42,
        )
        try:
            res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
        except Exception as e:  # noqa: BLE001 — report and keep going
            print(f"{tid:30s}  ERROR {type(e).__name__}: {str(e)[:60]}")
            continue

        # the decisive call: the last tool call the agent made
        decisive = "-"
        for msg in res.messages:
            for tc in getattr(msg, "tool_calls", None) or []:
                decisive = f"{tc.name}({tc.arguments})"
        print(f"{tid:30s} {res.reward_info.reward:6.1f} {agent.call_count:5d}  {decisive}")


if __name__ == "__main__":
    main()