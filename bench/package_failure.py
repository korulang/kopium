#!/usr/bin/env python3
"""package_failure — turn a frozen failing run into a sealed challenge brief.

Usage: python3 package_failure.py <run_dir> [more_run_dirs...] --name <slug>
       [--focus "what the challenger should attack"] [--catalog-only]

Emits challenges/<slug>/CHALLENGE.md + catalog/ dir. The brief is
templated on challenges/airline-failure-replay/CHALLENGE.md — evidence
paths, cogs inventory, anti-cheat wall, done gates, judging rubric —
with the specimen's autopsy hints filled from the run's own receipts.
"""
import argparse
import json
import re
import sys
from pathlib import Path

KOPIUM = Path(__file__).resolve().parent.parent
CHALLENGES = KOPIUM / "challenges"


def run_summary(run_dir: Path) -> dict:
    """Pull the autopsy hints a contestant needs, from receipts only."""
    s = {"dir": str(run_dir), "task": "?", "fatal": False,
         "reward": None, "calls": 0, "errors": [], "last_call_msgs": 0}
    m = re.search(r"task(\d+)", run_dir.name)
    if m:
        s["task"] = m.group(1)
    receipt = run_dir / "receipt.json"
    if receipt.exists():
        r = json.loads(receipt.read_text())
        s["model"] = r.get("agent_llm") or r.get("model", "?")
        s["demo"] = r.get("KOPIUM_DEMO", "")
        s["git_head"] = r.get("git_head", "?")
    traj = run_dir / "trajectory.txt"
    if traj.exists():
        txt = traj.read_text(errors="replace")
        # FATAL runs end mid-collapse with no ###STOP###; completed
        # episodes (win or zero) always terminate on it.
        s["fatal"] = "###STOP###" not in txt[-2000:]
        calls = re.findall(r"TOOL (\w+)", txt)
        s["calls"] = len(calls)
    else:
        # run_airline.py writes trajectory.txt only after run_simulation
        # returns — a FATAL crash leaves receipts but no trajectory.
        s["fatal"] = True
    rec = run_dir / "receipts"
    if rec.exists():
        cfiles = sorted(rec.glob("call_*.json"))
        s["calls"] = max(s["calls"], len(cfiles))
        if cfiles:
            try:
                msgs = json.loads(cfiles[-1].read_text())["messages"]
                s["last_call_msgs"] = len(msgs)
            except Exception:
                pass
        errs = {}
        for cf in rec.glob("callsteps_*.jsonl"):
            for line in cf.read_text(errors="replace").splitlines():
                try:
                    r = json.loads(line)
                except Exception:
                    continue
                oc = r.get("item_outcome", "")
                if oc not in ("ok", "delivered", "bound", ""):
                    key = f"{r.get('verb','?')}:{oc}"
                    errs[key] = errs.get(key, 0) + 1
        s["errors"] = sorted(errs.items(), key=lambda x: -x[1])[:8]
    return s


TEMPLATE = """---
challenge: {slug}
kind: frame
status: standing
yields: one verified fix to the doctrine/periphery layer, replay-proven
created: {created}
---

*Walker context: a packaged agent failure, replayed by contestants who
propose the smallest domain-general fix and prove it by re-running the
falsifier. Output drains into the codebase as fixes — the catalog holds
the judged submissions, not a growing variant shelf.*

---

## The brief (sealed — you are the contestant)

You are a contestant. You are given FROZEN failing run(s) of the KOPIUM
airline agent on tau2-bench. Your job: propose the smallest change to
the doctrine/periphery layer that prevents this failure class — and prove
it by replay, not by argument. Multiple contestants may attack the same
specimen; the catalog keeps the judged survivors — variance in METHOD is
the metric, convergence on the fix is the goal.

{focus_block}
**Self-ground first:** read `challenges/{slug}/catalog/` before proposing
— do not re-submit an already-adopted fix. Prior submissions are the
catalog you diverge from.

## The sealed evidence package (all paths absolute)

{evidence}

- Discipline contract: `/Users/larsde/src/kopium/.claude/skills/bench-verify/SKILL.md`
  — READ FIRST. Oracle hierarchy, autopsy order, spend rules.
- Experiment log: `/Users/larsde/src/n-grams/fable-pack/BRIEF-R5.md`

## The surface you are fixing (read this first)

The agent runs the NATIVE protocol — NOT the old transliterated
surface. Contract: `/Users/larsde/src/kopium/bench/native-protocol.k`
(declarations, named outcome branches, `std/runtime:register`).
Implementation: `/Users/larsde/src/kopium/bench/airline_native.kz`
(proc bodies, phantom types `string<found>`/`<chosen>`/`<user-known>`/
`<reservation-known>`/`<held!>`, branch classification).
Doctrine: `/Users/larsde/src/kopium/bench/guides/*.md` — external
files referenced by `std/guide:add(<tor> -> <branch>) @"guides/..."`.
`!` marks the only real obligation (<held!>); every other phantom is
typed borrow data. Scope is hardcoded `airline-native` — there is no
KOPIUM_SCOPE env var anymore.

## The machinery you may modify (the "defined cogs")

All in `/Users/larsde/src/kopium/bench/`:

- `native-protocol.k` — declarations, branch names, registry, guide keys
- `airline_native.kz` — procs: callIO args, branch classification,
  phantom mint/borrow handling
- `guides/*.md` — doctrine prose per (tor, branch); `{{ slot }}`
  templates resolve against bindings (MISSING = produce it first)
- `tau_wire.kz` — `callIO` (enforcement guards, WMFX watch), seed-text
- `tau-agent.k` — exemplars (`demo-seed`, strike exemplars) — must speak
  native syntax (`| found`, handles) or they teach refusals
- `guide_table.txt` — REGENERATED by `sh build-airline-gate.sh`
  (never hand-edit)

## Hard constraints (the anti-cheat wall)

1. **Domain-general only.** Doctrine must come from tau2's
   `data/tau2/domains/airline/policy.md` or train-30 corpus patterns —
   NEVER test-set ids (tasks 30-49), never this task's specifics.
2. **Progressive disclosure, not answer keys.** Teach how to behave —
   never hand over this task's resolution.
3. **No benchmark semantic changes.** tau2-bench stays unmodified.
4. **Local only.** `KOPIUM_API_URL=http://localhost:11434/v1/chat/completions`,
   `KOPIUM_REASONING=none`, `OPENROUTER_API_KEY=dummy`,
   `OLLAMA_API_BASE=http://localhost:11434`,
   `--llm ollama/qwen2.5-coder:14b --agent-llm qwen2.5-coder:14b`.
   NO paid endpoints, NO agent commissions.
5. **Rebuild discipline.** After editing `.k`/`.kz`: `koruc tau-agent.k &&
   mv a.out tau-agent-binary`; `sh build-airline-gate.sh` regenerates
   guide_table. Verify: `python3 gate_probe.py` (24/24) and
   `python3 guides-replay.py` (93/93 + dark) must stay green.

## Done gates (all must pass, in order)

1. **Autopsy first.** Read the failing run's LAST `call_*.json` — dump
   every message. Name the exact failure mechanism with receipt evidence.
   (Trajectory-only conclusions are rejected.)
2. **Propose the minimal fix.** One cog, smallest diff. State what it
   teaches and why it generalizes.
3. **Replay the falsifier(s).** Re-run the packaged task(s) with your
   change. The run must not FATAL; reward is reported but the gate is
   "the packaged failure class does not recur."
4. **Regression check.** Re-run at least one sibling task — the fix
   must not break a currently-passing behavior.
5. **Green harness.** gate_probe + guides-replay still pass.
6. **Submit.** Write your submission to
   `challenges/{slug}/catalog/<your-name>.md` — autopsy, the FULL diff
   (runnable, not described), replay receipt paths, honest limits.
   A catalog entry that can't be run or re-applied is a lie.

## Judging (how stupid is it)

Ranked by ascending impressiveness: smallest domain-general diff that
passes all gates wins. A fix that hardcodes task content, keys on task
id, or injects the answer fails review regardless of reward. A fix that
is general but doesn't survive replay fails the gates. The catalog
keeps only survivors — losers are documented, not deleted.
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dirs", nargs="+")
    ap.add_argument("--name", required=True)
    ap.add_argument("--focus", default="")
    ap.add_argument("--catalog-only", action="store_true",
                    help="print summary, don't write files")
    args = ap.parse_args()

    runs = [run_summary(Path(d)) for d in args.run_dirs]
    if args.catalog_only:
        print(json.dumps(runs, indent=1))
        return

    slug = args.name
    cdir = CHALLENGES / slug
    (cdir / "catalog").mkdir(parents=True, exist_ok=True)

    evidence_lines = []
    for s in runs:
        err_str = ", ".join(f"{v}×{k}" for k, v in s["errors"]) or "none recorded"
        evidence_lines.append(
            f"- Failing run (task {s['task']}): `{s['dir']}`\n"
            f"  - model `{s.get('model','?')}`, KOPIUM_DEMO=`{s.get('demo','')}`, "
            f"git `{s.get('git_head','?')}`\n"
            f"  - {'FATAL/prose-collapse' if s['fatal'] else 'zero-reward'} episode, "
            f"{s['calls']} model calls, last request {s['last_call_msgs']} messages\n"
            f"  - dominant callstep errors: {err_str}\n"
            f"  - receipts: `{s['dir']}/receipts/call_*.json`, "
            f"`callsteps_*.jsonl`, `trajectory.txt`"
        )
    focus_block = (f"## Focus\n\n{args.focus}\n\n" if args.focus else "")
    brief = TEMPLATE.format(slug=slug, focus_block=focus_block,
                            evidence="\n".join(evidence_lines),
                            created=__import__("datetime").date.today().isoformat())
    (cdir / "CHALLENGE.md").write_text(brief)
    print(f"wrote {cdir}/CHALLENGE.md")
    for s in runs:
        print(f"  task {s['task']}: {'FATAL' if s['fatal'] else 'reward-run'}, "
              f"{s['calls']} calls, errors: {s['errors'][:3]}")


if __name__ == "__main__":
    sys.exit(main())
