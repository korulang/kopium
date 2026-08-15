"""Baseline: the harness's OWN reference agent (JSON-schema tool calls) on the
same airline task 0. Answers 'is our 1.0 good?' — if the reference also lands
1.0, the task discriminates no one yet; if it does not, the refusal is doing
real work."""

import sys
from pathlib import Path

from tau2.agent.llm_agent import LLMAgent
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

LLM = "openrouter/anthropic/claude-haiku-4.5"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 else "0"
    env = build_environment("airline")
    task = get_tasks("airline", task_ids=[task_id])[0]

    agent = LLMAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        llm=LLM,
    )
    user = build_user("user_simulator", env, task, llm=LLM)
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
    print(f"stock LLMAgent reward: {res.reward_info.reward}")
    print(f"db: {res.reward_info.db_check}")
    print(f"calls: {agent.call_count if hasattr(agent, 'call_count') else 'n/a'}")
    for i, m in enumerate(res.messages):
        tcs = getattr(m, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                print(f"  [{i}] TOOL {tc.name}")
            continue
        c = (str(m.content) or "")[:80]
        print(f"  [{i}] {type(m).__name__}: {c}")


if __name__ == "__main__":
    main()