#!/usr/bin/env python3
"""
Head-to-head: KOPIUM (Koru gate) vs the harness's stock LLMAgent (JSON-schema
tools) on the same tasks, same seed, same model. Writes a CSV.

  python3 bench/run_compare.py [start] [count] [--suffix NAME]
  e.g. run_compare.py 0 50            # airline tasks 0..49
       run_compare.py 0 12 --suffix quick
       run_compare.py --ids 0,10,26  --suffix refusal   # explicit tasks
       run_compare.py 0 29 --suffix refresh \
           --stock-from results/compare_full50_taught.csv \
           --stock-from results/compare_smoke_r.csv    # later files win
       ... --koru-from results/compare_smoke_koru.csv  # same, for the koru arm
       run_compare.py 0 50 --suffix board --no-stock --resume
       # --no-stock: koru arm only, stock columns blank (never runs LLMAgent)
       # --resume: reload this suffix's own CSV and skip tasks already done

Output: bench/results/compare_<suffix>.csv
  task, koru_reward, koru_db, koru_calls, koru_prompt_tokens,
  koru_completion_tokens, koru_cost, koru_wall_s,
  stock_reward, stock_db, stock_calls, stock_prompt_tokens,
  stock_completion_tokens, stock_cost, stock_wall_s, notes
"""

from __future__ import annotations

import csv
import json
import os
import sys
import time
from pathlib import Path

import litellm
from tau2.agent.llm_agent import LLMAgent
from tau2.config import DEFAULT_MAX_ERRORS, DEFAULT_MAX_STEPS
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.data_model.message import AssistantMessage
from tau2.evaluator.evaluator import EvaluationType
from tau2.utils.llm_utils import get_token_usage

from kopium_agent import KopiumAgent

from model_guard import guard_llm

HERE = Path(__file__).parent
# Model for all three roles (koru agent, stock agent, user sim) — same-model
# fairness. BENCH_MODEL overrides for arm comparisons. guard_llm is the wall:
# Anthropic slugs exit at startup (burned ~$20/run twice — 2026-08-15 haiku,
# 2026-10-11 sonnet) unless BENCH_ALLOW_ANTHROPIC=1 is set per invocation.
LLM = guard_llm(os.environ.get("BENCH_MODEL", "unset/no-openrouter-default"))

# LiteLLM's price table lacks the v4.1-flash slug, so completion_cost()
# returns 0 and every message logs "model isn't mapped". Register the
# OpenRouter-published price for this exact slug so the existing cost
# plumbing (message.cost, get_cost, SimulationRun.agent_cost) produces real
# numbers. $0.30/M prompt, $1.20/M completion (api/v1/models, verified
# 2026-10-12).
litellm.model_cost["openrouter/deepseek/deepseek-v4.1-flash"] = {
    "input_cost_per_token": 0.3e-6,
    "output_cost_per_token": 1.2e-6,
    "max_tokens": 1048576,
    "litellm_provider": "openrouter",
    "mode": "chat",
}

# poolside laguna-s-2.1 :free — zero-cost twin for smoke runs and failure
# forensics. OpenRouter lists $0/$0, 262144 ctx (api/v1/models, 2026-10-18).
# Registered at exactly $0 so the unknown-price guard passes while the CSV
# still records a real (zero) cost. Rate limits apply — ~20 req/min, daily
# cap — so this arm smokes, it does not board.
litellm.model_cost["openrouter/poolside/laguna-s-2.1:free"] = {
    "input_cost_per_token": 0.0,
    "output_cost_per_token": 0.0,
    "max_tokens": 262144,
    "litellm_provider": "openrouter",
    "mode": "chat",
}

# poolside laguna-s-2.1 paid — the :free twin's uncapped sibling for boards.
# $0.09/M prompt, $0.18/M completion, 1M ctx (api/v1/models, 2026-10-18) —
# ~4x cheaper input than the deepseek default, so a full board costs dimes.
litellm.model_cost["openrouter/poolside/laguna-s-2.1"] = {
    "input_cost_per_token": 0.09e-6,
    "output_cost_per_token": 0.18e-6,
    "max_tokens": 1048576,
    "litellm_provider": "openrouter",
    "mode": "chat",
}

# z-ai glm-flash — the ~alias resolves server-side to z-ai/glm-5.3-flash, so
# both spellings are registered ($0.048/M prompt, $0.16/M completion;
# api/v1/models, 2026-10-19).
litellm.model_cost["openrouter/~z-ai/glm-flash-latest"] = {
    "input_cost_per_token": 0.048e-6,
    "output_cost_per_token": 0.16e-6,
    "max_tokens": 131072,
    "litellm_provider": "openrouter",
    "mode": "chat",
}
litellm.model_cost["openrouter/z-ai/glm-5.3-flash"] = dict(
    litellm.model_cost["openrouter/~z-ai/glm-flash-latest"])

# moonshotai kimi-k3 — smart-smart probe tier. $0.24/M prompt, $11.94/M
# completion (api/v1/models, 2026-10-19): output is ~50x the cheap tier, so
# this arm is for single-task probes, not boards.
litellm.model_cost["openrouter/moonshotai/kimi-k3"] = {
    "input_cost_per_token": 0.239e-6,
    "output_cost_per_token": 11.936e-6,
    "max_tokens": 262144,
    "litellm_provider": "openrouter",
    "mode": "chat",
}

# meta muse-spark-1.3-contributor — same band as laguna ($0.10/$0.20 per M,
# 1M ctx; api/v1/models, 2026-10-18), suspected stronger instruction
# following. Paired smoke arm against the same task ids.
litellm.model_cost["openrouter/meta/muse-spark-1.3-contributor"] = {
    "input_cost_per_token": 0.10e-6,
    "output_cost_per_token": 0.20e-6,
    "max_tokens": 1048576,
    "litellm_provider": "openrouter",
    "mode": "chat",
}

# A model litellm can't price logs $0 and leaves blank cost columns — the
# claude29 CSVs recorded ~5.4M tokens at no dollar figure. Unknown-price is a
# startup error, not a silent zero.
try:
    litellm.get_model_info(LLM)
except Exception:
    sys.exit(
        f"BENCH_MODEL={LLM} has no price entry in litellm.model_cost — costs "
        f"would log as blank. Register its OpenRouter price in this file "
        f"(see the -0731 block above) before running."
    )

# The koru arm's reasoning effort (tau_wire.kz reads KOPIUM_REASONING). Stock
# runs exactly as tau2 ships it — provider defaults — because that is the
# opponent; recorded per row so the koru setting behind every number is visible.
REASONING = os.environ.get("KOPIUM_REASONING", "none")
# The binary reads KOPIUM_REASONING from its own env, and the spawned env
# inherits ours — but an UNSET var meant this label ("none") diverged from
# the wire (the binary's own default "medium"). Export the resolved value so
# the CSV's reasoning column and the request body can never disagree again.
os.environ["KOPIUM_REASONING"] = REASONING

# Stock arm decoding controls. Stock's litellm request otherwise carries ONLY
# model+messages+tools — provider defaults for temperature, max_tokens and
# reasoning, which is exactly the asymmetry that made the deepseek pair
# uninterpretable (koru temp:0/medium vs stock defaults, measured 2026-10-19).
# STOCK_REASONING mirrors KOPIUM_REASONING: "none" → enabled:false via
# extra_body, "default" → omit the field, an effort literal → {"effort": X}.
# STOCK_TEMPERATURE sets temperature explicitly; unset stays provider default.
STOCK_REASONING = os.environ.get("STOCK_REASONING", "default")
STOCK_TEMPERATURE = os.environ.get("STOCK_TEMPERATURE")
stock_llm_args: dict = {}
if STOCK_REASONING == "none":
    stock_llm_args["extra_body"] = {"reasoning": {"enabled": False}}
elif STOCK_REASONING != "default":
    stock_llm_args["extra_body"] = {"reasoning": {"effort": STOCK_REASONING}}
if STOCK_TEMPERATURE is not None:
    stock_llm_args["temperature"] = float(STOCK_TEMPERATURE)

# The koru agent's wire requests already carry temperature:0 (receipt-verified).
# The user simulator ran at provider default — an unmeasured variance source:
# the sim samples a different conversation path each run, which alone flips
# pass/fail draws. tau2's own default is 0.0; USER_TEMPERATURE overrides.
USER_TEMPERATURE = os.environ.get("USER_TEMPERATURE", "0")
user_llm_args: dict = {"temperature": float(USER_TEMPERATURE)}


def run_one(agent_cls, task, domain, gate=None, receipt_dir=None, eval_path=None):
    env = build_environment(domain)
    if agent_cls is KopiumAgent:
        if receipt_dir is not None:
            receipt_dir.mkdir(parents=True, exist_ok=True)
            for f in receipt_dir.iterdir():
                f.unlink()
            os.environ["KOPIUM_RECEIPT_DIR"] = str(receipt_dir)
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
            llm_args=stock_llm_args or None,
        )
    user = build_user("user_simulator", env, task, llm=LLM,
                      llm_args=user_llm_args)
    orch = Orchestrator(
        domain=domain,
        agent=agent,
        user=user,
        environment=env,
        task=task,
        # tau2's own defaults (200/10), not a harness-local budget: the old
        # 40/5 punished the wire's transport granularity — the content channel
        # spends ~2 steps per call where stock batches — and scored protocol
        # cost as agent failure. measure.py learned this lesson first.
        max_steps=DEFAULT_MAX_STEPS,
        max_errors=DEFAULT_MAX_ERRORS,
        seed=42,
    )
    t0 = time.monotonic()
    res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
    wall_s = time.monotonic() - t0
    if eval_path is not None:
        Path(eval_path).parent.mkdir(parents=True, exist_ok=True)
        Path(eval_path).write_text(
            json.dumps(res.reward_info.model_dump(mode="json"), indent=2))
    r = res.reward_info
    db = getattr(r, "db_check", None)
    dbok = bool(db and db.db_match) if db else None
    calls = getattr(agent, "call_count", None)
    # Agent tokens only: the simulator stamps its own call's usage onto each
    # UserMessage (user_simulator.py), so a whole-transcript sum mixes sim
    # tokens into the agent's column. AssistantMessage.usage is the agent's
    # per-call usage for both arms (verified: koru's sum == session.json).
    usage = get_token_usage(
        [m for m in (res.messages or []) if isinstance(m, AssistantMessage)])
    tokens = (
        usage.get("prompt_tokens", 0),
        usage.get("completion_tokens", 0),
    )
    cost = res.agent_cost or 0.0
    return r.reward, dbok, calls, cost, tokens, wall_s


def main() -> None:
    suffix = "full"
    if "--suffix" in sys.argv:
        suffix = sys.argv[sys.argv.index("--suffix") + 1]

    out_dir = HERE / "results"
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / f"compare_{suffix}.csv"

    no_stock = "--no-stock" in sys.argv
    while "--no-stock" in sys.argv:
        sys.argv.remove("--no-stock")

    # --resume: this run's own CSV is already flushed one row per completed
    # task, so a killed sweep resumes by reusing its own rows.
    if "--resume" in sys.argv:
        sys.argv.remove("--resume")
        if out_path.exists():
            sys.argv += ["--koru-from", str(out_path),
                         "--stock-from", str(out_path)]
    # Early-exit guard: if koru is demonstrably losing by this many tasks and
    # this large a margin, stop the run instead of burning hours on a verdict
    # the first N tasks already delivered. `--no-guard` disables.
    guard_check = int(sys.argv[sys.argv.index("--guard-check") + 1]) if "--guard-check" in sys.argv else 10
    guard_margin = float(sys.argv[sys.argv.index("--guard-margin") + 1]) if "--guard-margin" in sys.argv else 0.30
    guard_enabled = "--no-guard" not in sys.argv

    # Reuse results from prior CSVs, per arm — the unit of invalidation is
    # a row, not the run. --stock-from reuses the unchanged stock harness;
    # --koru-from reuses koru rows the caller judges still valid (e.g. a
    # smoke run under the same agent code). Later files override earlier
    # ones (freshest last on the command line).
    #
    # Stock never changes between iterations, and it is stochastic — a fresh
    # stock run is a different draw, not a better one. So the comparator is
    # frozen: results/stock_baseline.csv loads automatically unless
    # --stock-from is given or --stock-fresh forces a re-run (headline
    # boards only — a fresh baseline is set by copying a chosen CSV there).
    if (not no_stock
            and "--stock-from" not in sys.argv and "--stock-fresh" not in sys.argv
            and (HERE / "results" / "stock_baseline.csv").exists()):
        sys.argv += ["--stock-from", str(HERE / "results" / "stock_baseline.csv")]
    while "--stock-fresh" in sys.argv:
        sys.argv.remove("--stock-fresh")
    stock_reuse: dict[str, dict] = {}
    koru_reuse: dict[str, dict] = {}
    for flag, dest in (("--stock-from", stock_reuse), ("--koru-from", koru_reuse)):
        while flag in sys.argv:
            i = sys.argv.index(flag)
            sys.argv.pop(i)
            src = Path(sys.argv.pop(i))
            if not src.is_absolute():
                src = (HERE / src).resolve()
            arm = "stock" if dest is stock_reuse else "koru"
            with open(src) as rf:
                for r in csv.DictReader(rf):
                    if not r.get(f"{arm}_reward"):
                        continue
                    dest[r["task"]] = {
                        "reward": float(r[f"{arm}_reward"]),
                        "db": r[f"{arm}_db"] == "True",
                        "calls": r[f"{arm}_calls"] or None,
                        "ptok": int(r[f"{arm}_prompt_tokens"] or 0),
                        "ctok": int(r[f"{arm}_completion_tokens"] or 0),
                        "cost": float(r[f"{arm}_cost"] or 0),
                        "wall": float(r[f"{arm}_wall_s"] or 0),
                        "src": src.name,
                    }

    domain = "airline"
    if "--ids" in sys.argv:
        ids = sys.argv[sys.argv.index("--ids") + 1].split(",")
        tasks = get_tasks(domain, task_ids=ids)
    else:
        start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        tasks = get_tasks(domain)
        tasks = tasks[start : start + count]
    print(f"domain={domain} tasks={len(tasks)} suffix={suffix} model={LLM} koru_reasoning={REASONING} stock_reasoning={STOCK_REASONING} stock_temp={STOCK_TEMPERATURE or 'provider-default'} no_stock={no_stock}", flush=True)
    rows = []
    with open(out_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["task", "model", "reasoning", "koru_reward", "koru_db", "koru_calls",
                    "koru_prompt_tokens", "koru_completion_tokens",
                    "koru_cost", "koru_wall_s",
                    "stock_reward", "stock_db", "stock_calls",
                    "stock_prompt_tokens", "stock_completion_tokens",
                    "stock_cost", "stock_wall_s", "notes"])
        for task in tasks:
            tid = task.id
            print(f"--- {tid} (t+{time.time():.0f})", flush=True)
            notes = ""
            if tid in koru_reuse:
                k = koru_reuse[tid]
                kr, kdb, kcalls = k["reward"], k["db"], k["calls"]
                ktok = (k["ptok"], k["ctok"])
                kcost, kwall = k["cost"], k["wall"]
                notes = f"koru: reused {k['src']}"
            else:
                try:
                    (kr, kdb, kcalls, kcost, ktok, kwall) = run_one(
                        KopiumAgent, task, domain,
                        gate=os.environ.get("KOPIUM_GATE", str(HERE / "tau-agent-binary")),
                        receipt_dir=HERE / "results" / "runs" / f"compare-{suffix}-task{tid}" / "receipts",
                        eval_path=HERE / "results" / "runs" / f"compare-{suffix}-task{tid}" / "eval.json",
                    )
                except Exception as e:  # noqa: BLE001
                    kr, kdb, kcalls, kcost, ktok, kwall = None, None, None, None, (None, None), None
                    notes = f"koru err: {e}"
                    print(f"    koru ERROR: {e}", flush=True)
                    if "requires more credits" in str(e):
                        print("ABORT: OpenRouter 402 — account is out of credits, "
                              "every remaining task would be an error row.", flush=True)
                        break
            if tid in stock_reuse:
                s = stock_reuse[tid]
                sr, sdb, scalls = s["reward"], s["db"], s["calls"]
                stok = (s["ptok"], s["ctok"])
                scost, swall = s["cost"], s["wall"]
                notes += f" | stock: reused {s['src']}"
            elif no_stock:
                sr, sdb, scalls, scost, stok, swall = None, None, None, None, (None, None), None
            else:
                try:
                    (sr, sdb, scalls, scost, stok, swall) = run_one(
                        LLMAgent, task, domain,
                        eval_path=HERE / "results" / "runs" / f"compare-{suffix}-task{tid}-stock" / "eval.json",
                    )
                except Exception as e:  # noqa: BLE001
                    sr, sdb, scalls, scost, stok, swall = None, None, None, None, (None, None), None
                    notes += f" | stock err: {e}"
                    print(f"    stock ERROR: {e}", flush=True)
                    if "requires more credits" in str(e):
                        print("ABORT: OpenRouter 402 — account is out of credits, "
                              "every remaining task would be an error row.", flush=True)
                        break
            row = [tid, LLM, REASONING, kr, kdb, kcalls, *ktok, round(kcost, 4) if kcost else None, round(kwall, 1) if kwall else None,
                   sr, sdb, scalls, *stok, round(scost, 4) if scost else None, round(swall, 1) if swall else None,
                   notes]
            rows.append(row)
            w.writerow(row)
            f.flush()
            print(f"    => koru {kr} (db={kdb}, n={kcalls}, cost=${kcost if kcost is not None else '--'}, wall={kwall if kwall is not None else '--'}s) "
                  f"| stock {sr} (db={sdb}, n={scalls}, cost=${scost if scost is not None else '--'}, wall={swall if swall is not None else '--'}s)", flush=True)

            krn = sum(1 for r in rows if r[3] and r[3] > 0)
            srn = sum(1 for r in rows if r[10] and r[10] > 0)
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
    krn = sum(1 for r in rows if r[3] and r[3] > 0)
    srn = sum(1 for r in rows if r[10] and r[10] > 0)
    total_costs = [0.0, 0.0]
    for r in rows:
        if r[8]:
            total_costs[0] += r[8]
        if r[15]:
            total_costs[1] += r[15]
    print(f"done: {len(rows)} tasks, {out_path}" + ("  [EARLY-STOPPED]" if aborted else ""))
    print(f"koru>0: {krn}/{len(rows)}  stock>0: {srn}/{len(rows)}")
    print(f"total cost: koru=${total_costs[0]:.4f} stock=${total_costs[1]:.4f}")


if __name__ == "__main__":
    main()