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

import datetime
import json
import os
import subprocess
import sys
from pathlib import Path

from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from kopium_agent import KopiumAgent
from model_guard import guard_llm

HERE = Path(__file__).parent
AGENT_BIN = HERE / "tau-agent-binary"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 else "0"
    llm = "openrouter/deepseek/deepseek-v4-flash-0731"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]
    llm = guard_llm(llm)

    if not AGENT_BIN.exists():
        sys.exit(f"kopium agent missing: build it in {HERE} with koruc tau-agent.k && mv a.out tau-agent-binary")

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

    agent = KopiumAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        domain="airline", gate_binary=AGENT_BIN,
        llm=llm,
    )

    # ------------------------------- run receipt -----------------------------
    # Every measured run prints and stores exactly what the model saw plus the
    # code state that produced it. No number gets quoted without this header.
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = HERE / "results" / "runs" / f"{stamp}-task{task.id}"
    run_dir.mkdir(parents=True, exist_ok=True)
    # The prompt is built and receipted inside the Koru process: one file per
    # model call, the exact request body it sent.
    receipt_dir = run_dir / "receipts"
    receipt_dir.mkdir(exist_ok=True)
    os.environ["KOPIUM_RECEIPT_DIR"] = str(receipt_dir)
    git_head = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True
    ).stdout.strip()
    git_dirty = subprocess.run(
        ["git", "status", "--porcelain"], capture_output=True, text=True
    ).stdout.strip()
    receipt = {
        "task": task.id,
        "model": llm,
        "git_head": git_head,
        "git_dirty_files": [l[3:] for l in git_dirty.splitlines()],
        "receipt_dir": str(receipt_dir),
    }
    (run_dir / "receipt.json").write_text(json.dumps(receipt, indent=1))
    print("=" * 60)
    print("RUN RECEIPT")
    for k, v in receipt.items():
        print(f"  {k}: {v}")
    print("=" * 60)

    print(f"task      : {task.id}")
    print(f"golden    : {actions or '(no tool calls - the refusal)'}")
    print(f"asked     : {str(inst)[:140]}")
    print()

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
    traj_lines = []
    for i, m in enumerate(res.messages):
        tcs = getattr(m, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                line = f"  [{i}] TOOL {tc.name}({tc.arguments})"
                print(line)
                traj_lines.append(line)
            continue
        c = (str(m.content) or "")[:160]
        line = f"  [{i}] {type(m).__name__}: {c}"
        print(line)
        traj_lines.append(line)
    (run_dir / "trajectory.txt").write_text("\n".join(traj_lines) + "\n")
    print(f"\nrun dir   : {run_dir}")


if __name__ == "__main__":
    main()