#!/usr/bin/env python3
"""Stock-arm twin of run_airline.py — same task, same llm, LLMAgent."""
import sys
from pathlib import Path
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType
from tau2.agent.llm_agent import LLMAgent

def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 else "0"
    llm = "openrouter/deepseek/deepseek-v4-flash-0731"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]
    env = build_environment("airline")
    tasks = get_tasks("airline", task_ids=[task_id])
    task = tasks[0]
    agent = LLMAgent(tools=env.get_tools(), domain_policy=env.get_policy(),
                     llm=llm, llm_args={"reasoning_effort": "none"})
    user = build_user("user_simulator", env, task, llm=llm)
    orch = Orchestrator(domain="airline", agent=agent, user=user,
                        environment=env, task=task, max_steps=40,
                        max_errors=5, seed=42)
    res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
    print("=" * 60)
    print(f"reward : {res.reward_info.reward}")
    print(f"db_check: {res.reward_info.db_check}")
    print("trajectory:")
    for i, m in enumerate(res.messages):
        tcs = getattr(m, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                print(f"  [{i}] TOOL {tc.name}({tc.arguments})")
            continue
        print(f"  [{i}] {type(m).__name__}: {(str(m.content) or '')[:200]}")

if __name__ == "__main__":
    main()
