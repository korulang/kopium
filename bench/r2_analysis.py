#!/usr/bin/env python3
"""r2_analysis.py — BRIEF-R2 artifacts from call_step records.

Reads per-run callsteps_*.jsonl out of a measure.py kopium config dir
(default: the R2 sweep, results/measure/kopium-1b8b218752b3), validates
the record schema, and produces:

  corpus    -> bench/corpus/r2-callstep.jsonl      (merged, provenance-stamped)
  transitions -> bench/tables/r2-transitions.json  ((tor,branch) -> next tor)
  scoreboard metrics -> stdout (the .md is written by hand from these)

Subcommands:
  collect     scan + validate + write corpus + per-run summary JSON
  transitions build the (tor,branch) -> next table from the corpus dir scan
  scoreboard  compute the §6 rows computable from records + reward
  noise       compare two run dirs (baseline vs reflight) field by field

Denominator conventions (methodology §3 "rates from records"):
  - "dispatch" = a call_step record with origin=="model" and verb != "".
  - "item"     = a (run, turn, step) group; zero-dispatch items carry
                 verb=="" records and are counted as item events, never
                 as dispatches.
  - harness-origin records (origin=="harness") are excluded from every
    rate, per methodology §4/PCA:439-441.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCH = HERE
MEASURE = BENCH / "results" / "measure"
R2_KEY = "1b8b218752b3"
CORPUS = BENCH / "corpus" / "r2-callstep.jsonl"
TABLE = BENCH / "tables" / "r2-transitions.json"
RUNS_R2 = BENCH / "results" / "r2"

SEED_BASE = 42
MODEL = "openrouter/deepseek/deepseek-v4-flash-0731"

REQUIRED_KEYS = {
    "type", "origin", "seq", "turn", "step", "of", "item_outcome",
    "state_hash", "verb", "args", "armed", "arm_word", "arm_name",
    "branch", "payload", "bound", "handles", "used", "fired_guides",
    "failed", "error",
}

ITEM_REFUSALS = {
    "parse-error", "validation-error", "shape-error", "event-denied",
    "dispatch-error", "scope-not-found", "exhausted", "residue",
    "defined", "partial", "abandoned",
}


def run_dirs(measure_dir: Path) -> list[Path]:
    return sorted(
        p for p in measure_dir.glob("task*/trial*") if p.is_dir()
    )


def read_callsteps(d: Path) -> tuple[list[dict], list[str]]:
    """All call_step records in a run dir + malformed-line notes."""
    recs: list[dict] = []
    problems: list[str] = []
    files = sorted((d / "receipts").glob("callsteps_*.jsonl"))
    if not files:
        problems.append("no callsteps_*.jsonl in receipts")
        return recs, problems
    for f in files:
        for n, line in enumerate(f.read_text().splitlines(), 1):
            if not line.strip():
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError as e:
                problems.append(f"{f.name}:{n} bad JSON: {e}")
                continue
            if not isinstance(r, dict):
                problems.append(f"{f.name}:{n} not an object")
                continue
            missing = REQUIRED_KEYS - set(r)
            if missing:
                problems.append(
                    f"{f.name}:{n} missing keys {sorted(missing)}")
            recs.append(r)
    return recs, problems


def run_reward(d: Path) -> tuple[float | None, str]:
    """(reward, source): sim.json reward_info.reward, else error.json."""
    sim = d / "sim.json"
    if sim.exists():
        try:
            ri = (json.loads(sim.read_text()).get("reward_info") or {})
            r = ri.get("reward")
            return (float(r) if r is not None else None), "sim.json"
        except Exception:
            return None, "sim.json-unparseable"
    err = d / "error.json"
    if err.exists():
        return None, "error.json"
    return None, "no-artifact"


def provenance(d: Path, cfg: dict, config_key: str) -> dict:
    task = d.parent.name.removeprefix("task")
    trial = int(d.name.removeprefix("trial"))
    return {
        "task": task,
        "trial": trial,
        "seed": SEED_BASE + trial,
        "run_dir": str(d.relative_to(BENCH)),
        "config_key": config_key,
        "agent_binary_sha256": cfg.get("agent_binary_sha256"),
        "tool_doc_sha256": cfg.get("tool_doc_sha256"),
        "model": cfg.get("llm"),
        "user_llm": cfg.get("user_llm"),
        "tau2_head": cfg.get("tau2_head"),
        "channel": cfg.get("channel"),
        "scope": cfg.get("scope"),
        # KOPIUM_REASONING was unset for the sweep -> binary default "medium"
        # (tau_wire.kz:1101). measure.py's config_key does not capture it.
        "reasoning_effort": "medium",
        "reasoning_source": "binary-default (KOPIUM_REASONING unset)",
    }


def cmd_collect(measure_dir: Path, flight: str, out_corpus: Path,
                want_tasks: set[str] | None, config_key: str,
                trial_range: tuple[int, int] | None = None) -> dict:
    cfg_path = measure_dir / "config.json"
    cfg = (json.loads(cfg_path.read_text()) if cfg_path.exists() else {})
    out_corpus.parent.mkdir(parents=True, exist_ok=True)
    summary = {"runs": [], "problems": [], "totals": Counter()}
    n_written = 0
    with out_corpus.open("w") as out:
        for d in run_dirs(measure_dir):
            task = d.parent.name.removeprefix("task")
            if want_tasks is not None and task not in want_tasks:
                continue
            trial = int(d.name.removeprefix("trial"))
            if (trial_range is not None
                    and not trial_range[0] <= trial <= trial_range[1]):
                continue
            recs, problems = read_callsteps(d)
            reward, rsrc = run_reward(d)
            prov = provenance(d, cfg, config_key)
            prov["flight"] = flight
            prov["reward"] = reward
            summary["runs"].append({
                "dir": str(d.relative_to(BENCH)),
                "task": task, "trial": prov["trial"],
                "records": len(recs), "problems": problems,
                "reward": reward, "reward_source": rsrc,
            })
            summary["problems"].extend(
                f"{d.relative_to(BENCH)}: {p}" for p in problems)
            summary["totals"]["records"] += len(recs)
            summary["totals"]["runs"] += 1
            summary["totals"]["malformed_lines"] += len(problems)
            for r in recs:
                row = dict(r)
                row.update(prov)
                out.write(json.dumps(row, ensure_ascii=False) + "\n")
                n_written += 1
    summary["corpus_rows_written"] = n_written
    return summary


def cmd_coverage(corpus_path: Path, declared_path: Path) -> dict:
    """Declared-edge coverage: which (tor, branch) pairs in airline_tools.k
    were ever dispatched in the corpus. Dark edges are classified by
    exposure: 'tor-never-dispatched' vs 'branch-never-observed' (with the
    tor's observed branch histogram). No edge is declared 'unspeakable'
    here — speakability is a tool-side property this miner cannot prove;
    every dark edge is reported as never-observed with its exposure."""
    declared = declared_edges(declared_path)
    declared_set = {(t, b) for t, bs in declared.items() for b in bs}
    obs: Counter = Counter()                    # (tor, branch) -> dispatches
    tor_tot: Counter = Counter()                # tor -> dispatches
    tor_br: dict[str, Counter] = defaultdict(Counter)
    nxt_of: dict[tuple, Counter] = defaultdict(Counter)
    edge_tasks: dict[tuple, set] = defaultdict(set)
    edge_rewards: dict[tuple, Counter] = defaultdict(Counter)
    n_dispatch = 0
    n_runs = 0
    for run_key, run in iter_runs(corpus_path):
        n_runs += 1
        ds = [r for r in run["recs"]
              if r.get("origin") == "model" and r.get("verb")]
        rw = run["prov"].get("reward")
        rwc = ("pos" if (rw or 0) > 0 else
               "zero" if rw == 0 else "unknown")
        task = run["prov"].get("task", "?")
        for i, r in enumerate(ds):
            n_dispatch += 1
            tor, br = r["verb"], _branch_of(r)
            obs[(tor, br)] += 1
            tor_tot[tor] += 1
            tor_br[tor][br] += 1
            nxt = ds[i + 1]["verb"] if i + 1 < len(ds) else "<end>"
            nxt_of[(tor, br)][nxt] += 1
            edge_tasks[(tor, br)].add(task)
            edge_rewards[(tor, br)][rwc] += 1

    observed_declared = sorted(k for k in declared_set if obs.get(k))
    dark = sorted(declared_set - set(observed_declared))
    undeclared = sorted(k for k in obs if k not in declared_set)

    edges = {}
    for tor, br in sorted(declared_set | set(obs)):
        is_decl = (tor, br) in declared_set
        entry = {
            "declared": is_decl,
            "count": obs.get((tor, br), 0),
            "tor_dispatches": tor_tot.get(tor, 0),
            "tor_branches": dict(tor_br.get(tor, {})),
            "next": dict(nxt_of[(tor, br)].most_common())
                    if obs.get((tor, br)) else {},
            "tasks": sorted(edge_tasks.get((tor, br), ())),
            "reward": dict(edge_rewards.get((tor, br), {})),
        }
        if is_decl and not obs.get((tor, br)):
            if tor_tot.get(tor, 0) == 0:
                entry["dark_reason"] = "tor-never-dispatched"
            else:
                entry["dark_reason"] = "branch-never-observed"
        edges[f"{tor}|{br}"] = entry

    return {
        "corpus": str(corpus_path.relative_to(BENCH)),
        "declared_source": str(declared_path.relative_to(BENCH)),
        "n_runs": n_runs,
        "n_dispatch_records": n_dispatch,
        "declared_edges": len(declared_set),
        "observed_declared_edges": len(observed_declared),
        "coverage_declared": (len(observed_declared) / len(declared_set)
                              if declared_set else None),
        "observed_(tor,branch)_pairs_total": len(obs),
        "undeclared_pairs": [f"{t}|{b}" for t, b in undeclared],
        "dark_edges": [
            {"edge": f"{t}|{b}",
             "reason": edges[f"{t}|{b}"]["dark_reason"],
             "tor_dispatches": tor_tot.get(t, 0),
             "tor_branches": dict(tor_br.get(t, {}))}
            for t, b in dark],
        "edges": edges,
    }


def _branch_of(rec: dict) -> str:
    """Outcome branch of a dispatch: payload.branch when present, else the
    matched arm word field, else ""."""
    p = rec.get("payload")
    if isinstance(p, dict) and p.get("branch"):
        return str(p["branch"])
    return str(rec.get("branch") or "")


def _identity(rec: dict) -> str:
    """Call identity for stall detection (Fable correction: analysis-side,
    state_hash can't do it). verb + resolved arg values + outcome branch."""
    args = rec.get("args") or []
    vals = sorted(
        (str(a.get("name")), str(a.get("value"))) for a in args
        if isinstance(a, dict))
    return json.dumps([rec.get("verb"), vals, _branch_of(rec)],
                      sort_keys=True)


def iter_runs(corpus_path: Path):
    """Yield (prov, [records]) per run, records seq-ordered, from corpus."""
    runs: dict[str, dict] = {}
    order: list[str] = []
    for line in corpus_path.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        key = r.get("run_dir") or "?"
        if key not in runs:
            runs[key] = {"prov": {k: r.get(k) for k in (
                "task", "trial", "seed", "flight", "reward",
                "agent_binary_sha256", "model", "run_dir")},
                "recs": []}
            order.append(key)
        runs[key]["recs"].append(r)
    for k in order:
        runs[k]["recs"].sort(key=lambda r: r.get("seq", 0))
        yield k, runs[k]


def cmd_transitions(corpus_path: Path, out_path: Path,
                    declared_path: Path) -> dict:
    declared = declared_edges(declared_path)
    edges: dict[str, dict] = {}
    sess_trans: dict[str, list] = {}
    n_dispatch = 0
    for run_key, run in iter_runs(corpus_path):
        recs = [r for r in run["recs"]
                if r.get("origin") == "model" and r.get("verb")]
        n_dispatch += len(recs)
        trans = []
        for i, r in enumerate(recs):
            nxt = recs[i + 1]["verb"] if i + 1 < len(recs) else "<end>"
            key = f"{r['verb']}|{_branch_of(r)}"
            e = edges.setdefault(key, {
                "from": {"tor": r["verb"], "branch": _branch_of(r)},
                "to": Counter(), "count": 0,
                "reward": Counter(), "tasks": Counter(),
                "declared": declared.get(r["verb"], []),
            })
            e["to"][nxt] += 1
            e["count"] += 1
            rw = run["prov"].get("reward")
            e["reward"]["pos" if (rw or 0) > 0 else
                        "zero" if rw == 0 else "unknown"] += 1
            e["tasks"][run["prov"].get("task", "?")] += 1
            trans.append((key, nxt))
        sess_trans[run_key] = trans

    # serialise
    table = {"meta": {
        "corpus": str(corpus_path.relative_to(BENCH)),
        "declared_source": str(declared_path.relative_to(BENCH)),
        "declared_edges": sum(len(v) for v in declared.values()),
        "n_dispatch_records": n_dispatch,
        "n_runs": len(sess_trans),
        "branch_field": "payload.branch else branch else \"\"",
        "next_sentinel": "<end> = last dispatch of the run",
    }, "edges": {}}
    for k in sorted(edges):
        e = edges[k]
        table["edges"][k] = {
            "from_tor": e["from"]["tor"],
            "from_branch": e["from"]["branch"],
            "declared_outcomes": e["declared"],
            "count": e["count"],
            "next": dict(e["to"].most_common()),
            "reward": dict(e["reward"]),
            "tasks": dict(e["tasks"].most_common(10)),
        }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(table, indent=1, sort_keys=True))
    return {"edges": len(edges), "dispatches": n_dispatch,
            "runs": len(sess_trans)}


def declared_edges(tools_k: Path) -> dict[str, list[str]]:
    """Declared (tor -> outcome branches) mined from airline_tools.k:
    `pub tor NAME ...` followed by `| branch type` lines."""
    out: dict[str, list[str]] = {}
    cur: str | None = None
    for line in tools_k.read_text().splitlines():
        m = re.match(r"\s*pub tor ([\w-]+)", line)
        if m:
            cur = m.group(1)
            out.setdefault(cur, [])
            continue
        if cur:
            b = re.match(r"\s*\|\s*([\w-]+)\s", line)
            if b:
                out[cur].append(b.group(1))
            elif line.strip() and not line.strip().startswith(("[", "]")):
                if not line.lstrip().startswith("|"):
                    cur = None
    return out


PRICE_PROMPT, PRICE_COMPLETION = 0.018e-6, 0.64e-6  # flash-0731 $/token


def _msg_tokens(sim: dict) -> tuple[int, int, int, int]:
    """(agent_ptok, agent_ctok, user_ptok, user_ctok) from sim.json messages.
    AssistantMessage.usage = agent calls; UserMessage.usage = user sim."""
    ap = ac = up = uc = 0
    for m in sim.get("messages") or []:
        u = m.get("usage") or {}
        pt, ct = u.get("prompt_tokens", 0), u.get("completion_tokens", 0)
        if m.get("role") == "assistant":
            ap += pt; ac += ct
        elif m.get("role") == "user":
            up += pt; uc += ct
    return ap, ac, up, uc


def cmd_scoreboard(corpus_path: Path, measure_dir: Path) -> dict:
    cfg = json.loads((measure_dir / "config.json").read_text())
    runs = list(iter_runs(corpus_path))
    n_runs = len(runs)

    # per-run aggregates
    per_run = []
    item_events = Counter()
    dispatch_fates = Counter()
    stall_events = 0
    n_dispatch = 0
    surprise_by_class = Counter()
    failed_sessions = 0
    silent_fail = 0
    rewards = Counter()

    for run_key, run in runs:
        prov = run["prov"]
        recs = run["recs"]
        model_recs = [r for r in recs if r.get("origin") == "model"]
        disp = [r for r in model_recs if r.get("verb")]
        items = defaultdict(list)
        for r in model_recs:
            items[(r.get("turn"), r.get("step"))].append(r)
        rw = prov.get("reward")
        rewards["pos" if (rw or 0) > 0 else
                "zero" if rw == 0 else "unknown"] += 1

        run_surprise = 0
        # item-level events (zero-dispatch records carry verb=="")
        for (t, s), rs in items.items():
            io = rs[0].get("item_outcome")
            has_disp = any(r.get("verb") for r in rs)
            if io in ITEM_REFUSALS:
                item_events[io] += 1
                run_surprise += 1
            if io == "unhandled-branch":
                # attach to the dispatch records of the item whose arm
                # did not match (arm_word == "")
                unmatched = [r for r in rs
                             if r.get("verb") and not r.get("arm_word")]
                if unmatched:
                    cls = ("armed-mismatch" if any(r.get("armed")
                                                   for r in unmatched)
                           else "unarmed-outcome")
                    surprise_by_class[cls] += len(unmatched)
                    run_surprise += len(unmatched)
                else:
                    surprise_by_class["unarmed-outcome"] += 1
                    run_surprise += 1
        for r in disp:
            n_dispatch += 1
            dispatch_fates["failed" if r.get("failed") else "ok"] += 1
            if r.get("failed"):
                surprise_by_class["refusal-dispatch"] += 1
                run_surprise += 1
        # stall: repeated call identity within the run
        seen = Counter(_identity(r) for r in disp)
        st = sum(c - 1 for c in seen.values() if c > 1)
        stall_events += st
        if st:
            surprise_by_class["stall"] += st
            run_surprise += st

        if rw == 0:
            failed_sessions += 1
            if run_surprise == 0:
                silent_fail += 1
        # cost: agent (assistant) + user sim (user) tokens at flash-0731
        cost_agent = cost_user = wall = None
        rd = BENCH / (prov.get("run_dir") or "")
        simj = rd / "sim.json"
        if simj.exists():
            try:
                s = json.loads(simj.read_text())
                ap, ac, up, uc = _msg_tokens(s)
                cost_agent = ap * PRICE_PROMPT + ac * PRICE_COMPLETION
                cost_user = up * PRICE_PROMPT + uc * PRICE_COMPLETION
            except Exception:
                pass
        rj = rd / "run.json"
        if rj.exists():
            try:
                wall = json.loads(rj.read_text()).get("wall_s")
            except Exception:
                pass
        per_run.append({
            "run_dir": prov.get("run_dir"), "task": prov.get("task"),
            "trial": prov.get("trial"), "reward": rw,
            "n_dispatch": len(disp), "n_model_records": len(model_recs),
            "n_records": len(recs), "surprise_events": run_surprise,
            "cost_agent": cost_agent, "cost_user": cost_user,
            "wall_s": wall,
        })

    out = {
        "runs": n_runs,
        "dispatches": n_dispatch,
        "rewards": dict(rewards),
        "failed_sessions_reward0": failed_sessions,
        "silent_failures": silent_fail,
        "silent_failure_rate": (silent_fail / failed_sessions
                                if failed_sessions else None),
        "item_events": dict(item_events),
        "surprise_by_class": dict(surprise_by_class),
        "surprise_rate_per_dispatch": {
            k: (v / n_dispatch if n_dispatch else None)
            for k, v in surprise_by_class.items()},
        "stall_events": stall_events,
        "dispatch_fates": dict(dispatch_fates),
        "cost_agent_total": sum(r["cost_agent"] or 0 for r in per_run),
        "cost_user_total": sum(r["cost_user"] or 0 for r in per_run),
        "predictive": _predictive(runs),
        "per_run": per_run,
    }
    return out


def _predictive(runs: list) -> dict:
    """Top-k next-verb prediction: train the (tor,branch)->next table on
    trial0 runs, score it on trial1 runs. Baseline = branch-blind
    tor->next marginal. Only keys present in the train table are scored
    (coverage reported alongside — methodology §5 'Priors sharpen')."""
    def dispatches(run):
        return [r for r in run["recs"]
                if r.get("origin") == "model" and r.get("verb")]

    train_next: dict[str, Counter] = defaultdict(Counter)
    train_tor: dict[str, Counter] = defaultdict(Counter)
    glob_next: Counter = Counter()
    for _, run in runs:
        if run["prov"].get("trial") != 0:
            continue
        ds = dispatches(run)
        for i, r in enumerate(ds):
            nxt = ds[i + 1]["verb"] if i + 1 < len(ds) else "<end>"
            train_next[f"{r['verb']}|{_branch_of(r)}"][nxt] += 1
            train_tor[r["verb"]][nxt] += 1
            glob_next[nxt] += 1
    if not train_next:
        return {"note": "no trial0 runs"}

    total_test = 0
    scored = top1 = top3 = base_hit = 0
    for _, run in runs:
        if run["prov"].get("trial") != 1:
            continue
        ds = dispatches(run)
        for i, r in enumerate(ds):
            nxt = ds[i + 1]["verb"] if i + 1 < len(ds) else "<end>"
            total_test += 1
            key = f"{r['verb']}|{_branch_of(r)}"
            if key not in train_next:
                continue
            scored += 1
            ranked = [v for v, _ in train_next[key].most_common()]
            if ranked and ranked[0] == nxt:
                top1 += 1
            if nxt in ranked[:3]:
                top3 += 1
            bt = train_tor[r["verb"]].most_common(1)
            if bt and bt[0][0] == nxt:
                base_hit += 1
    n = scored or 1
    return {
        "train": "trial0", "test": "trial1",
        "test_transitions": total_test,
        "scored_transitions": scored,
        "key_coverage": scored / total_test if total_test else None,
        "top1": top1, "top1_acc": top1 / n,
        "top3": top3, "top3_acc": top3 / n,
        "branch_blind_top1": base_hit, "branch_blind_acc": base_hit / n,
    }


def cmd_noise(dir_a: Path, dir_b: Path) -> dict:
    """Compare two flights of identical inputs, field by field."""
    def load(d: Path):
        recs, probs = read_callsteps(d)
        sim = d / "sim.json"
        reward = None
        if sim.exists():
            reward = ((json.loads(sim.read_text())
                       .get("reward_info") or {}).get("reward"))
        sess = d / "receipts" / "session.json"
        sessj = json.loads(sess.read_text()) if sess.exists() else {}
        return recs, reward, sessj, probs

    ra, ra_reward, sa, pa = load(dir_a)
    rb, rb_reward, sb, pb = load(dir_b)
    ma = [r for r in ra if r.get("origin") == "model"]
    mb = [r for r in rb if r.get("origin") == "model"]

    def sig(recs):
        return [(r.get("verb"), _branch_of(r), r.get("item_outcome"),
                 r.get("arm_word")) for r in recs]

    def surprises(recs):
        c = Counter()
        items = defaultdict(list)
        for r in recs:
            items[(r.get("turn"), r.get("step"))].append(r)
        for rs in items.values():
            io = rs[0].get("item_outcome")
            if io in ITEM_REFUSALS:
                c[io] += 1
            if io == "unhandled-branch":
                un = [r for r in rs if r.get("verb") and not r.get("arm_word")]
                c["armed-mismatch" if any(r.get("armed") for r in un)
                  else "unarmed-outcome"] += max(1, len(un))
        seen = Counter(_identity(r) for r in recs if r.get("verb"))
        c["stall"] = sum(v - 1 for v in seen.values() if v > 1)
        return c

    ca, cb = surprises(ma), surprises(mb)
    keys = sorted(set(ca) | set(cb))
    return {
        "a": str(dir_a), "b": str(dir_b),
        "reward_a": ra_reward, "reward_b": rb_reward,
        "records_a": len(ra), "records_b": len(rb),
        "model_records_a": len(ma), "model_records_b": len(mb),
        "dispatch_a": sum(1 for r in ma if r.get("verb")),
        "dispatch_b": sum(1 for r in mb if r.get("verb")),
        "surprise_a": dict(ca), "surprise_b": dict(cb),
        "surprise_keys": {k: [ca.get(k, 0), cb.get(k, 0)] for k in keys},
        "sig_identical": sig(ma) == sig(mb),
        "session_a": {k: sa.get(k) for k in
                      ("model_calls", "prompt_tokens", "completion_tokens",
                       "rejected_turns", "residue_items")},
        "session_b": {k: sb.get(k) for k in
                      ("model_calls", "prompt_tokens", "completion_tokens",
                       "rejected_turns", "residue_items")},
        "problems_a": pa, "problems_b": pb,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["collect", "transitions",
                                    "scoreboard", "noise", "coverage"])
    ap.add_argument("--measure-dir", type=Path,
                    default=MEASURE / f"kopium-{R2_KEY}")
    ap.add_argument("--corpus", type=Path, default=CORPUS)
    ap.add_argument("--table", type=Path, default=TABLE)
    ap.add_argument("--flight", default="sweep")
    ap.add_argument("--tasks", default=None,
                    help="csv subset of task ids")
    ap.add_argument("--trial-min", type=int, default=None,
                    help="collect only: first trial index to include")
    ap.add_argument("--trial-max", type=int, default=None,
                    help="collect only: last trial index to include")
    ap.add_argument("--dir-a", type=Path)
    ap.add_argument("--dir-b", type=Path)
    ap.add_argument("--config-key", default=None)
    ap.add_argument("--summary-out", type=Path)
    a = ap.parse_args()
    for attr in ("measure_dir", "corpus", "table", "dir_a", "dir_b",
                 "summary_out"):
        v = getattr(a, attr)
        if v is not None:
            setattr(a, attr, v.resolve())

    if a.cmd == "collect":
        want = set(a.tasks.split(",")) if a.tasks else None
        tr = None
        if a.trial_min is not None or a.trial_max is not None:
            tr = (a.trial_min if a.trial_min is not None else 0,
                  a.trial_max if a.trial_max is not None else 10**9)
        key = a.config_key or (
            a.measure_dir.name.split("-", 1)[1]
            if a.measure_dir.name.startswith("kopium-") else "r2")
        s = cmd_collect(a.measure_dir, a.flight, a.corpus, want, key, tr)
        if a.summary_out:
            a.summary_out.write_text(json.dumps(s, indent=1))
        print(json.dumps({k: v for k, v in s.items()
                          if k != "runs"}, indent=1))
        for r in s["runs"]:
            print(f"  {r['dir']}: recs={r['records']} "
                  f"reward={r['reward']} problems={len(r['problems'])}")
    elif a.cmd == "transitions":
        declared = BENCH / "airline_tools.k"
        print(json.dumps(cmd_transitions(
            a.corpus, a.table, declared), indent=1))
    elif a.cmd == "scoreboard":
        print(json.dumps(cmd_scoreboard(a.corpus, a.measure_dir),
                         indent=1))
    elif a.cmd == "coverage":
        print(json.dumps(cmd_coverage(a.corpus,
                                      BENCH / "airline_tools.k"),
                         indent=1))
    elif a.cmd == "noise":
        print(json.dumps(cmd_noise(a.dir_a, a.dir_b), indent=1))


if __name__ == "__main__":
    main()
