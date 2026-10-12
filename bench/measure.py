#!/usr/bin/env python3
"""
Measure kopium vs tau2's stock LLMAgent on airline tasks: agent-only numbers.

  python3 bench/measure.py --ids 0,1,2 --trials 3 [--arms stock,kopium] [--jobs 4]
  python3 bench/measure.py --ids 0 --trials 1 --summarize-only

Every simulation is cached as raw data (the tau2 SimulationRun JSON, plus
kopium's receipts/ and session.json) under

  results/measure/<arm>-<config_key>/task<id>/trial<k>/

and metrics are DERIVED from that raw data, never stored as the only copy. The
config key hashes everything that could change an arm's behaviour; for the
stock arm that excludes kopium's code, so stock runs are reused across kopium
changes, and a kopium run is reused only while the binary and tool doc are
byte-identical. Failed runs write error.json and are re-run next time.

Parity between arms: same model, same user simulator, same agent llm settings
(temperature 0, reasoning effort none — kopium's tau-agent.k sends the same),
same max_steps / max_errors, seed = 42 + trial for both arms.

Agent-only metrics (the user simulator's tokens are excluded — tau2's
get_token_usage and agent_cost+user_cost mix them in):
  reward, db_match, termination, model_calls, prompt_tokens,
  completion_tokens, cost (tokens x one price table, both arms), env_calls,
  wall_s; kopium also: rejected_turns, rejections_by_kind, defines.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import signal
import statistics
import subprocess
import sys
import time
import traceback
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE / "results" / "measure"
TAU2_ROOT = HERE.parent.parent / "tau2-bench"

from model_guard import guard_llm

DOMAIN = "airline"
LLM = "openrouter/deepseek/deepseek-v4-flash-0731"
# Agent model for BOTH arms — KOPIUM_LLM overrides it for model A/B runs.
# The user simulator stays pinned to LLM so an agent-model delta is not
# confounded by a different simulated user. guard_llm is the wall: Anthropic
# slugs exit at startup unless BENCH_ALLOW_ANTHROPIC=1 (see model_guard.py).
AGENT_LLM = guard_llm(os.environ.get("KOPIUM_LLM", LLM))
AGENT_LLM_ARGS = {"temperature": 0.0, "reasoning_effort": "none"}
# tau2's own defaults (tau2/config.py), not a harness-local budget: the old
# 40/5 punished transport granularity (one env call per message) rather
# than agent quality.
from tau2.config import DEFAULT_MAX_ERRORS as MAX_ERRORS, DEFAULT_MAX_STEPS as MAX_STEPS
SEED_BASE = 42
# One price row per agent model (OpenRouter list price, the same figures
# run_compare.py registers with litellm). $/token. An unpriced model is a
# loud error — never a silently mispriced report.
PRICES = {
    # $0.018/M in, $0.64/M out — api/v1/models, verified 2026-10-11 (the old
    # $0.14/$0.28 row was stale: input ~8x high, output ~2.3x low).
    "openrouter/deepseek/deepseek-v4-flash-0731": (0.018e-6, 0.64e-6),
    "openrouter/google/gemini-2.5-flash": (0.30e-6, 2.50e-6),
    "openrouter/meta/muse-spark-1.3-contributor": (0.10e-6, 0.20e-6),
}
if AGENT_LLM not in PRICES:
    raise SystemExit(f"measure: no price row for agent model {AGENT_LLM} — add it to PRICES")
PRICE_PROMPT, PRICE_COMPLETION = PRICES[AGENT_LLM]

KOPIUM_BIN = HERE / "tau-agent-binary"
KOPIUM_DOC = HERE / "airline_vocab_doc.md"

# Hard wall-clock cap per simulation, enforced inside the worker (SIGALRM
# interrupts a blocked read because the handler raises). One wedged run —
# measured 2026-09-28: a marshal read blocked 50 min on a dead pipe — parked
# as_completed forever, silently. ~3x the slowest observed legit run.
RUN_TIMEOUT_S = 1800


class _RunTimeout(Exception):
    pass


def _alarm(_sig: int, _frame) -> None:
    raise _RunTimeout(f"run exceeded {RUN_TIMEOUT_S}s wall clock")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args],
                          capture_output=True, text=True).stdout.strip()


def config_key(arm: str) -> tuple[str, dict]:
    cfg = {
        "arm": arm,
        "domain": DOMAIN,
        "llm": AGENT_LLM,
        "channel": os.environ.get("KOPIUM_CHANNEL", "content"),
        "scope": os.environ.get("KOPIUM_SCOPE", "airline"),
        "agent_llm_args": AGENT_LLM_ARGS if arm == "stock" else None,
        "user_llm": LLM,
        "max_steps": MAX_STEPS,
        "max_errors": MAX_ERRORS,
        "tau2_head": _git(TAU2_ROOT, "rev-parse", "HEAD"),
    }
    if arm == "kopium":
        cfg["agent_binary_sha256"] = _sha(KOPIUM_BIN)
        cfg["tool_doc_sha256"] = _sha(KOPIUM_DOC)
    key = hashlib.sha256(json.dumps(cfg, sort_keys=True).encode()).hexdigest()[:12]
    return key, cfg


def run_dir(arm: str, key: str, task_id: str, trial: int) -> Path:
    return OUT / f"{arm}-{key}" / f"task{task_id}" / f"trial{trial}"


# --------------------------------------------------------------- one run
def run_one(arm: str, key: str, task_id: str, trial: int) -> str:
    """Runs in a worker process (os.environ is per-process there)."""
    from tau2.agent.llm_agent import LLMAgent
    from tau2.evaluator.evaluator import EvaluationType
    from tau2.orchestrator.orchestrator import Orchestrator
    from tau2.runner import build_environment, build_user, get_tasks, run_simulation
    from kopium_agent import KopiumAgent

    d = run_dir(arm, key, task_id, trial)
    d.mkdir(parents=True, exist_ok=True)
    (d / "error.json").unlink(missing_ok=True)
    signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(RUN_TIMEOUT_S)
    try:
        env = build_environment(DOMAIN)
        task = get_tasks(DOMAIN, task_ids=[task_id])[0]
        if arm == "kopium":
            receipts = d / "receipts"
            receipts.mkdir(exist_ok=True)
            for f in receipts.iterdir():
                f.unlink()
            os.environ["KOPIUM_RECEIPT_DIR"] = str(receipts)
            agent = KopiumAgent(tools=env.get_tools(), domain_policy=env.get_policy(),
                                domain=DOMAIN, gate_binary=KOPIUM_BIN, llm=AGENT_LLM)
        else:
            agent = LLMAgent(tools=env.get_tools(), domain_policy=env.get_policy(),
                             llm=AGENT_LLM, llm_args=dict(AGENT_LLM_ARGS))
        user = build_user("user_simulator", env, task, llm=LLM)
        orch = Orchestrator(domain=DOMAIN, agent=agent, user=user, environment=env,
                            task=task, max_steps=MAX_STEPS, max_errors=MAX_ERRORS,
                            seed=SEED_BASE + trial)
        t0 = time.monotonic()
        res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
        wall = time.monotonic() - t0
        (d / "sim.json").write_text(res.model_dump_json(indent=1))
        (d / "run.json").write_text(json.dumps({
            "wall_s": wall,
            "kopium_head": _git(HERE.parent, "rev-parse", "HEAD"),
            "kopium_dirty": _git(HERE.parent, "status", "--porcelain").splitlines(),
        }, indent=1))
        return f"{arm} task{task_id} trial{trial}: reward {res.reward_info.reward}"
    except Exception as e:  # noqa: BLE001 — recorded, and the run is not cached
        (d / "error.json").write_text(json.dumps(
            {"error": repr(e), "traceback": traceback.format_exc()}, indent=1))
        (d / "sim.json").unlink(missing_ok=True)
        return f"{arm} task{task_id} trial{trial}: ERROR {e!r}"
    finally:
        signal.alarm(0)


# --------------------------------------------------------------- integrity
def integrity_failures(d: Path) -> list[str]:
    """Kopium run: every tool result tau2 returned must reach the model.
    For each ToolMessage followed by any model call, some later receipt (an
    exact request body) must contain its full content as rendered inside the
    Value JSON. Returns one line per result the model never saw."""
    import datetime
    sim = json.loads((d / "sim.json").read_text())
    bodies = []
    for r in sorted((d / "receipts").glob("call_*.json")):
        req = json.loads(r.read_text())
        bodies.append((r.stat().st_mtime, "\n".join(m["content"] for m in req["messages"])))
    fails = []
    for m in sim["messages"]:
        if m["role"] != "tool":
            continue
        ts = datetime.datetime.fromisoformat(m["timestamp"]).timestamp()
        later = [seen for mt, seen in bodies if mt > ts]
        if later and not any(json.dumps(m["content"])[1:-1] in seen for seen in later):
            fails.append(f"{d}: tool result ({len(m['content'])} bytes, "
                         f"{m['content'][:60]!r}) never reached the model")
    return fails


# --------------------------------------------------------------- metrics
def metrics(arm: str, d: Path) -> dict:
    sim = json.loads((d / "sim.json").read_text())
    run = json.loads((d / "run.json").read_text())
    msgs = sim.get("messages") or []
    agent_msgs = [m for m in msgs if m.get("role") == "assistant"]
    # The orchestrator opens every conversation with a scripted greeting
    # ("Hi! How can I help you today?") on the agent's behalf: no model call,
    # no usage, no raw_data. It is not the agent's output — drop exactly that
    # one; any other assistant message without usage is an error below.
    if (msgs and msgs[0].get("role") == "assistant"
            and msgs[0].get("usage") is None and msgs[0].get("raw_data") is None):
        agent_msgs = agent_msgs[1:]
    ptok = ctok = 0
    for m in agent_msgs:
        u = m.get("usage")
        if u is None:
            raise RuntimeError(f"{d}: assistant message without usage")
        ptok += u["prompt_tokens"]
        ctok += u["completion_tokens"]
    env_calls = sum(len(m.get("tool_calls") or []) for m in agent_msgs)
    ri = sim.get("reward_info") or {}
    db = ri.get("db_check")
    row = {
        "arm": arm,
        "task": sim["task_id"],
        "trial": d.name.removeprefix("trial"),
        "reward": ri.get("reward"),
        "db_match": db.get("db_match") if db else None,
        "termination": sim.get("termination_reason"),
        "agent_messages": len(agent_msgs),
        "env_calls": env_calls,
        "prompt_tokens": ptok,
        "completion_tokens": ctok,
        "wall_s": round(run["wall_s"], 1),
    }
    if arm == "stock":
        row["model_calls"] = len(agent_msgs)
    else:
        sess_path = d / "receipts" / "session.json"
        n_receipts = len(list((d / "receipts").glob("call_*.json")))
        if not sess_path.exists():
            # Zero-call run: the sim ended before the agent was ever asked
            # (user ###STOP### on turn 0) — the binary never spawned.
            # Receipts without a session are a mid-session death; stay loud.
            if n_receipts:
                raise RuntimeError(
                    f"{d}: {n_receipts} call receipts but no session.json — "
                    f"the run died mid-session")
            row["model_calls"] = 0
            row["rejected_turns"] = 0
            row["defines"] = 0
            row["residue_items"] = 0
            row["implicit_say"] = 0
            row["rejections_by_kind"] = "{}"
            row["cost"] = round(ptok * PRICE_PROMPT + ctok * PRICE_COMPLETION, 6)
            return row
        sess = json.loads(sess_path.read_text())
        if sess["model_calls"] != n_receipts:
            raise RuntimeError(f"{d}: session model_calls {sess['model_calls']} != receipts {n_receipts}")
        if (sess["prompt_tokens"], sess["completion_tokens"]) != (ptok, ctok):
            # A transfer-terminated sim drops the terminal assistant message —
            # the transfer tool call ends the run before tau2 records it, so
            # its usage leaves the message sum while session.json still counts
            # the call. Tolerate a session-side surplus only there; messages
            # carrying more than the session spent is always a desync.
            transferred = any(
                "###TRANSFER###" in (m.get("content") or "") for m in msgs)
            if not (transferred and sess["prompt_tokens"] > ptok
                    and sess["completion_tokens"] >= ctok):
                raise RuntimeError(
                    f"{d}: session tokens {sess['prompt_tokens']}/{sess['completion_tokens']} "
                    f"!= tokens on outbound messages {ptok}/{ctok}")
        blind = integrity_failures(d)
        if blind:
            raise RuntimeError("INTEGRITY: " + "; ".join(blind))
        row["model_calls"] = sess["model_calls"]
        row["rejected_turns"] = sess["rejected_turns"]
        row["defines"] = sess["defines"]
        row["residue_items"] = sess.get("residue_items", 0)
        row["implicit_say"] = sess.get("implicit_say", 0)
        row["rejections_by_kind"] = json.dumps(
            {k: v for k, v in sess["rejections_by_kind"].items() if v})
    row["cost"] = round(ptok * PRICE_PROMPT + ctok * PRICE_COMPLETION, 6)
    return row


COLUMNS = ["arm", "task", "trial", "reward", "db_match", "termination",
           "model_calls", "agent_messages", "env_calls", "prompt_tokens",
           "completion_tokens", "cost", "wall_s", "rejected_turns", "defines",
           "residue_items", "implicit_say", "rejections_by_kind"]


def summarize(rows: list[dict]) -> None:
    for arm in sorted({r["arm"] for r in rows}):
        rs = [r for r in rows if r["arm"] == arm]
        n = len(rs)
        passed = sum(1 for r in rs if (r["reward"] or 0) > 0)

        def med(k: str):
            return statistics.median(r[k] for r in rs)

        print(f"{arm:7s} n={n:3d}  pass {passed}/{n} ({passed / n * 100:.0f}%)  "
              f"median: model_calls {med('model_calls')}  prompt_tok {med('prompt_tokens')}  "
              f"completion_tok {med('completion_tokens')}  wall {med('wall_s')}s  "
              f"total cost ${sum(r['cost'] for r in rs):.4f}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True)
    ap.add_argument("--trials", type=int, default=1)
    ap.add_argument("--arms", default="stock,kopium")
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--suffix", default="latest")
    ap.add_argument("--summarize-only", action="store_true")
    ap.add_argument("--ungated", action="store_true",
                    help="fuzz only: skip the smoke-PASS gate on the kopium arm")
    a = ap.parse_args()

    ids = a.ids.split(",")
    arms = a.arms.split(",")
    keys = {}
    for arm in arms:
        key, cfg = config_key(arm)
        keys[arm] = key
        (OUT / f"{arm}-{key}").mkdir(parents=True, exist_ok=True)
        (OUT / f"{arm}-{key}" / "config.json").write_text(json.dumps(cfg, indent=1))
        print(f"{arm}: config {key}", flush=True)

    if "kopium" in arms and not a.summarize_only:
        gate = OUT / f"smoke-{keys['kopium']}.json"
        if not gate.exists() and not a.ungated:
            sys.exit(f"refusing to run the kopium arm: no smoke PASS for this binary "
                     f"({gate.name} missing). Run `python3 bench/smoke.py` first.")

    jobs = [(arm, keys[arm], tid, k) for arm in arms for tid in ids for k in range(a.trials)]
    todo = [j for j in jobs if not (run_dir(*j) / "sim.json").exists()]
    print(f"{len(jobs)} runs, {len(jobs) - len(todo)} cached, {len(todo)} to run", flush=True)
    if todo and not a.summarize_only:
        with ProcessPoolExecutor(max_workers=a.jobs) as ex:
            futs = {ex.submit(run_one, *j): j for j in todo}
            for fut in as_completed(futs):
                print("  " + fut.result(), flush=True)
                j = futs[fut]
                d = run_dir(*j)
                blind = (integrity_failures(d)
                         if j[0] == "kopium" and (d / "sim.json").exists() else [])
                if blind:
                    for f in futs:
                        f.cancel()
                    sys.exit("STOPPED — core-path defect, the model did not see tool results:\n  "
                             + "\n  ".join(blind))

    rows, missing = [], []
    for j in jobs:
        d = run_dir(*j)
        if (d / "sim.json").exists():
            rows.append(metrics(j[0], d))
        else:
            missing.append(str(d))
    out_csv = OUT / f"summary_{a.suffix}.csv"
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"wrote {out_csv} ({len(rows)} rows)")
    if missing:
        print(f"MISSING {len(missing)} runs (see error.json):")
        for m in missing:
            print("  " + m)
    if rows:
        summarize(rows)


if __name__ == "__main__":
    sys.path.insert(0, str(HERE))
    main()
