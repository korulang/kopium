#!/usr/bin/env python3
"""
Head-to-head: KOPIUM (Koru gate) vs the harness's stock LLMAgent (JSON-schema
tools) on the same tasks, same seed, same model. Writes a CSV.

  python3 bench/run_compare.py [start] [count] [--suffix NAME]
  e.g. run_compare.py 0 50            # airline tasks 0..49
       run_compare.py 0 12 --suffix quick

Output: bench/results/compare_<suffix>.csv
  task, koru_reward, koru_db, koru_calls, stock_reward, stock_db, notes
"""

from __future__ import annotations

import csv
import sys
import time
from pathlib import Path

from tau2.agent.llm_agent import LLMAgent
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from kopium_agent import KopiumAgent

HERE = Path(__file__).parent
LLM = "openrouter/deepseek/deepseek-v4-flash-0731"


def run_one(agent_cls, task, domain, gate=None):
    env = build_environment(domain)
    if agent_cls is KopiumAgent:
        agent = agent_cls(
            tools=env.get_tools(),
            domain_policy=env.get_policy(),
            domain=domain,
            gate_binary=gate,
            llm=LLM,
        )
    else:
        agent = agent_cls(
            tools=env.get_tools(),
            domain_policy=env.get_policy(),
            llm=LLM,
        )
    user = build_user("user_simulator", env, task, llm=LLM)
    orch = Orchestrator(
        domain=domain,
        agent=agent,
        user=user,
        environment=env,
        task=task,
        max_steps=40,
        max_errors=5,
        seed=42,
    )
    res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
    r = res.reward_info
    db = getattr(r, "db_check", None)
    dbok = bool(db and db.db_match) if db else None
    calls = getattr(agent, "call_count", None)
    return r.reward, dbok, calls, agent


def main() -> None:
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    suffix = "full"
    if "--suffix" in sys.argv:
        suffix = sys.argv[sys.argv.index("--suffix") + 1]

    domain = "airline"
    tasks = get_tasks(domain)
    window = tasks[start : start + count]
    out_dir = HERE / "results"
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / f"compare_{suffix}.csv"

    print(f"domain={domain} tasks={len(window)} start={start} suffix={suffix}", flush=True)
    rows = []
    with open(out_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["task", "koru_reward", "koru_db", "koru_calls",
                    "stock_reward", "stock_db", "stock_calls", "notes"])
        for task in window:
            tid = task.id
            print(f"--- {tid} (t+{time.time():.0f})", flush=True)
            notes = ""
            try:
                kr, kdb, kcalls, _ = run_one(
                    KopiumAgent, task, domain, gate=str(HERE / "airline-gate-binary")
                )
            except Exception as e:  # noqa: BLE001
                kr, kdb, kcalls, notes = None, None, None, f"koru err: {e}"
                print(f"    koru ERROR: {e}", flush=True)
            try:
                sr, sdb, scalls, _ = run_one(LLMAgent, task, domain)
            except Exception as e:  # noqa: BLE001
                sr, sdb, scalls = None, None, None
                notes += f" | stock err: {e}"
                print(f"    stock ERROR: {e}", flush=True)
            row = [tid, kr, kdb, kcalls, sr, sdb, scalls, notes]
            rows.append(row)
            w.writerow(row)
            f.flush()
            print(f"    => koru {kr} (db={kdb}, n={kcalls}) | stock {sr} (db={sdb}, n={scalls})", flush=True)

    ok = sum(1 for r in rows if r[1] and r[1] > 0)
    print(f"done: {len(rows)} tasks, {out_path}")
    print(f"koru>0: {ok}/{len(rows)}")


if __name__ == "__main__":
    main()