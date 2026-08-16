#!/usr/bin/env python3
"""
Head-to-head: KOPIUM (Koru gate) vs the harness's stock LLMAgent (JSON-schema
tools) on the same tasks, same seed, same model. Writes a CSV.

  python3 bench/run_compare.py [start] [count] [--suffix NAME]
  e.g. run_compare.py 0 50            # airline tasks 0..49
       run_compare.py 0 12 --suffix quick
       run_compare.py --ids 0,10,26  --suffix refusal   # explicit tasks

Output: bench/results/compare_<suffix>.csv
  task, koru_reward, koru_db, koru_calls, koru_prompt_tokens,
  koru_completion_tokens, koru_cost, koru_wall_s,
  stock_reward, stock_db, stock_calls, stock_prompt_tokens,
  stock_completion_tokens, stock_cost, stock_wall_s, notes
"""

from __future__ import annotations

import csv
import sys
import time
from pathlib import Path

import litellm
from tau2.agent.llm_agent import LLMAgent
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType
from tau2.utils.llm_utils import get_token_usage

from kopium_agent import KopiumAgent

HERE = Path(__file__).parent
LLM = "openrouter/deepseek/deepseek-v4-flash-0731"

# LiteLLM's price table has "deepseek/deepseek-v4-flash" but not the -0731
# slug, so completion_cost() returns 0 and every message logs "model isn't
# mapped". Register the OpenRouter-published price for this exact slug so the
# existing cost plumbing (message.cost, get_cost, SimulationRun.agent_cost)
# produces real numbers. $0.14/M prompt, $0.28/M completion.
litellm.model_cost["openrouter/deepseek/deepseek-v4-flash-0731"] = {
    "input_cost_per_token": 0.14e-6,
    "output_cost_per_token": 0.28e-6,
    "max_tokens": 163840,
    "litellm_provider": "openrouter",
    "mode": "chat",
}


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
    t0 = time.monotonic()
    res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
    wall_s = time.monotonic() - t0
    r = res.reward_info
    db = getattr(r, "db_check", None)
    dbok = bool(db and db.db_match) if db else None
    calls = getattr(agent, "call_count", None)
    usage = get_token_usage(res.messages or [])
    tokens = (
        usage.get("prompt_tokens", 0),
        usage.get("completion_tokens", 0),
    )
    cost = (res.agent_cost or 0.0) + (res.user_cost or 0.0)
    return r.reward, dbok, calls, cost, tokens, wall_s


def main() -> None:
    suffix = "full"
    if "--suffix" in sys.argv:
        suffix = sys.argv[sys.argv.index("--suffix") + 1]
    # Early-exit guard: if koru is demonstrably losing by this many tasks and
    # this large a margin, stop the run instead of burning hours on a verdict
    # the first N tasks already delivered. `--no-guard` disables.
    guard_check = int(sys.argv[sys.argv.index("--guard-check") + 1]) if "--guard-check" in sys.argv else 10
    guard_margin = float(sys.argv[sys.argv.index("--guard-margin") + 1]) if "--guard-margin" in sys.argv else 0.30
    guard_enabled = "--no-guard" not in sys.argv

    domain = "airline"
    if "--ids" in sys.argv:
        ids = sys.argv[sys.argv.index("--ids") + 1].split(",")
        tasks = get_tasks(domain, task_ids=ids)
    else:
        start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        tasks = get_tasks(domain)
        window = tasks[start : start + count]
    out_dir = HERE / "results"
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / f"compare_{suffix}.csv"

    print(f"domain={domain} tasks={len(tasks)} suffix={suffix}", flush=True)
    rows = []
    with open(out_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["task", "koru_reward", "koru_db", "koru_calls",
                    "koru_prompt_tokens", "koru_completion_tokens",
                    "koru_cost", "koru_wall_s",
                    "stock_reward", "stock_db", "stock_calls",
                    "stock_prompt_tokens", "stock_completion_tokens",
                    "stock_cost", "stock_wall_s", "notes"])
        for task in tasks:
            tid = task.id
            print(f"--- {tid} (t+{time.time():.0f})", flush=True)
            notes = ""
            try:
                (kr, kdb, kcalls, kcost, ktok, kwall) = run_one(
                    KopiumAgent, task, domain, gate=str(HERE / "airline-gate-binary")
                )
            except Exception as e:  # noqa: BLE001
                kr, kdb, kcalls, kcost, ktok, kwall = None, None, None, None, (None, None), None
                notes = f"koru err: {e}"
                print(f"    koru ERROR: {e}", flush=True)
            try:
                (sr, sdb, scalls, scost, stok, swall) = run_one(LLMAgent, task, domain)
            except Exception as e:  # noqa: BLE001
                sr, sdb, scalls, scost, stok, swall = None, None, None, None, (None, None), None
                notes += f" | stock err: {e}"
                print(f"    stock ERROR: {e}", flush=True)
            row = [tid, kr, kdb, kcalls, *ktok, round(kcost, 4) if kcost else None, round(kwall, 1) if kwall else None,
                   sr, sdb, scalls, *stok, round(scost, 4) if scost else None, round(swall, 1) if swall else None,
                   notes]
            rows.append(row)
            w.writerow(row)
            f.flush()
            print(f"    => koru {kr} (db={kdb}, n={kcalls}, cost=${kcost if kcost is not None else '--'}, wall={kwall if kwall is not None else '--'}s) "
                  f"| stock {sr} (db={sdb}, n={scalls}, cost=${scost if scost is not None else '--'}, wall={swall if swall is not None else '--'}s)", flush=True)

            krn = sum(1 for r in rows if r[1] and r[1] > 0)
            srn = sum(1 for r in rows if r[8] and r[8] > 0)
            done = len(rows)
            if krn and srn:
                print(f"    tally {done:2d}: koru {krn:2d} ({krn/done*100:3.0f}%)  stock {srn:2d} ({srn/done*100:3.0f}%)  gap {srn-krn:+d}", flush=True)
                if guard_enabled and done >= guard_check:
                    gap = (srn - krn) / done
                    if gap >= guard_margin and srn > krn:
                        print(f"EARLY-STOP: at {done} tasks koru {krn}/{done} vs stock {srn}/{done} "
                              f"(gap {gap*100:.0f}pts ≥ {guard_margin*100:.0f}) — losing is established, stopping.", flush=True)
                        break

    aborted = len(rows) < len(tasks)
    krn = sum(1 for r in rows if r[1] and r[1] > 0)
    srn = sum(1 for r in rows if r[8] and r[8] > 0)
    total_costs = [0.0, 0.0]
    for r in rows:
        if r[6]:
            total_costs[0] += r[6]
        if r[13]:
            total_costs[1] += r[13]
    print(f"done: {len(rows)} tasks, {out_path}" + ("  [EARLY-STOPPED]" if aborted else ""))
    print(f"koru>0: {krn}/{len(rows)}  stock>0: {srn}/{len(rows)}")
    print(f"total cost: koru=${total_costs[0]:.4f} stock=${total_costs[1]:.4f}")


if __name__ == "__main__":
    main()