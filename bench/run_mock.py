#!/usr/bin/env python3
"""
Run the KOPIUM mock-domain pilot against tau3-bench.

Builds the environment, wire our Koru gate into a HalfDuplexAgent, runs ONE
task, prints the reward and the conversation. The pilot's bar: a tool call
survives the Koru gate, tau3 executes it on its fake DB, the result comes
back, and the run scores.

Usage:
    python3 bench/run_mock.py [task_id] [--llm openrouter/...]

No API key is needed for the mock domain's tools; the model call needs an
LLM credential the same way every tau run does (.env / LiteLLM).
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.agent.base_agent import HalfDuplexAgent
from tau2.data_model.message import (
    APICompatibleMessage,
    AssistantMessage,
    Message,
    SystemMessage,
    UserMessage,
)
from tau2.evaluator.evaluator import EvaluationType
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation

from kopium_agent import KopiumAgent

HERE = Path(__file__).parent
GATE = HERE / "mock-gate-binary"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 else "create_task_1"
    llm = "openai/gpt-4.1-mini"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]

    if not GATE.exists():
        sys.exit(f"gate binary missing: build it first: cd {HERE} && koruc mock-gate.k")

    env = build_environment("mock")
    tasks = get_tasks("mock", task_ids=[task_id])
    if not tasks:
        sys.exit(f"no task {task_id!r} in the mock domain")
    task = tasks[0]

    print(f"Task      : {task.id} — {task.user_scenario.instructions[:90]}...")
    print(f"Domain    : mock — tools: {[t.name for t in env.get_tools()]}")
    print()

    agent = KopiumAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        gate_binary=GATE, domain="mock",
        llm=llm,
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

    result = run_simulation(orchestrator, evaluation_type=EvaluationType.ALL)

    print("=" * 60)
    print(f"Reward            : {result.reward_info.reward}")
    print(f"Agent calls       : {agent.call_count}")
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