#!/usr/bin/env python3
"""Run the mock domain with the LOCAL LLaDA2.2 agent (n-gram warm-start).

Same harness path as run_mock.py — tau2 orchestrator, evaluator, user sim —
but the agent is LocalLladaAgent: generation on this machine through
gen_server.py, legality through mock-gate-binary. The incumbent arm is
tau-agent.k + a hosted model; this arm isolates the local-generation
variable.

  python3 bench/run_mock_local.py [task_id] [--arm warm|base] [--steps N]

The user simulator still needs an LLM credential (.env / LiteLLM) — only
the AGENT side is local.
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from local_llada_agent import LocalLladaAgent

HERE = Path(__file__).parent
GATE = HERE / "mock-gate-binary"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "create_task_1"
    arm = "warm"
    steps = 16
    draft = "ngrams/llada22-o4-koru-k.pkl"
    draft_frac = 1.0
    if "--arm" in sys.argv:
        arm = sys.argv[sys.argv.index("--arm") + 1]
    if "--steps" in sys.argv:
        steps = int(sys.argv[sys.argv.index("--steps") + 1])
    if "--draft" in sys.argv:
        draft = sys.argv[sys.argv.index("--draft") + 1]
    if "--draft-frac" in sys.argv:
        draft_frac = float(sys.argv[sys.argv.index("--draft-frac") + 1])
    llm = "openai/gpt-4.1-mini"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]

    if not GATE.exists():
        sys.exit(f"gate binary missing: {GATE}")

    env = build_environment("mock")
    tasks = get_tasks("mock", task_ids=[task_id])
    if not tasks:
        sys.exit(f"no task {task_id!r} in the mock domain")
    task = tasks[0]

    print(f"Task      : {task.id} — {task.user_scenario.instructions[:90]}...")
    print(f"Agent     : local LLaDA2.2-mini arm={arm} steps={steps} draft={draft}")
    print(f"User sim  : {llm}")
    print()

    agent = LocalLladaAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        gate_binary=GATE,
        arm=arm,
        draft=draft,
        draft_frac=draft_frac,
        steps=steps,
    )
    user = build_user("user_simulator", env, task, llm=llm)

    orchestrator = Orchestrator(
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
        result = run_simulation(orchestrator, evaluation_type=EvaluationType.ALL)
    finally:
        print("\n===== agent trace =====")
        for line in agent.trace:
            print(line)
        agent.stop()

    print("=" * 60)
    print(f"Reward            : {result.reward_info.reward}")
    print(f"Agent calls       : {agent.call_count} (gen calls: {agent.gen_calls}, rejections: {agent.rejections})")
    print(f"Messages          : {len(result.messages)}")
    print()
    print("Conversation:")
    for i, msg in enumerate(result.messages):
        role = msg.role.value if hasattr(msg.role, "value") else msg.role
        tcs = getattr(msg, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                print(f"  [{role}] TOOL CALL {tc.name}({tc.arguments})")
            continue
        content = str(msg.content)[:200] if msg.content else "(empty)"
        print(f"  [{role}] {content}")


if __name__ == "__main__":
    main()
