#!/usr/bin/env python3
"""The frag-partial-programs experiment: composition vs the one-line law.

The fragment is explicit — "identical goals, multi-invocation turns vs the
one-line law, cost-per-task and reliability vote" — and guilty until measured
innocent. This drives one chained task (open → write → close) through two
arms:

  composed   — `headless/experiment.k` on the current intake (the whole turn
               reaches `std/bridge:run`, which sequences it)
  one-line   — the SAME program from a pre-flip worktree (the intake that
               truncated to the head and enforced one invocation per turn)

Only `app/wire` differs between the arms; the goals, model, budget, and turn
cap are identical. Cost is `[usage]` prompt+completion tokens summed per run;
reliability is whether exp.txt ends up holding exactly `alpha`.

  python3 bench/experiment.py [--n 3]
"""
from __future__ import annotations

import argparse
import re
import statistics
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BENCH = Path(__file__).resolve().parent
HEADLESS = REPO / "headless"
PREFLIP = Path.home() / "src" / "kopium-preflip"
PREFLIP_HEADLESS = PREFLIP / "headless"
PREFLIP_REF = "3d035e2"  # the pre-flip kopium commit (2f500f3~1)

USAGE_RE = re.compile(r"\[usage\] prompt (\d+) completion (\d+)")
TURN_RE = re.compile(r"^turn \d+", re.MULTILINE)
HOLDS_RE = re.compile(r"bridge now holds (\d+) resource")
STEP_RE = re.compile(r"steps: (\d+)/(\d+) ran")


def ensure_preflip() -> bool:
    """The control arm is the pre-flip intake: a worktree at PREFLIP_REF with
    the current experiment.k dropped in beside its (old) wire.kz."""
    if not PREFLIP_HEADLESS.exists():
        r = subprocess.run(["git", "worktree", "add", str(PREFLIP), PREFLIP_REF],
                           cwd=REPO, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr)
            return False
    (PREFLIP_HEADLESS / "experiment.k").write_bytes((HEADLESS / "experiment.k").read_bytes())
    return True


def compile_arm(directory: Path) -> Path | None:
    src = directory / "experiment.k"
    if not src.exists():
        print(f"  ! {src} missing")
        return None
    r = subprocess.run(["koruc", "experiment.k"], cwd=directory, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ! koruc failed in {directory}")
        print((r.stdout or "") + (r.stderr or ""))
        return None
    return directory / "a.out"


def run_once(binary: Path, directory: Path, logdir: Path, arm: str, n: int) -> dict:
    target = directory / "exp.txt"
    target.unlink(missing_ok=True)
    try:
        r = subprocess.run([str(binary)], cwd=directory, capture_output=True, text=True, timeout=240)
        out = (r.stdout or "") + (r.stderr or "")
        rc = r.returncode
        timed_out = False
    except subprocess.TimeoutExpired as e:
        out = ((e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")) + \
              ((e.stderr or b"").decode() if isinstance(e.stderr, bytes) else (e.stderr or ""))
        rc = -1
        timed_out = True
    logdir.mkdir(exist_ok=True)
    (logdir / f"{arm}-{n}.log").write_text(out)
    prompt = sum(int(m.group(1)) for m in USAGE_RE.finditer(out))
    completion = sum(int(m.group(2)) for m in USAGE_RE.finditer(out))
    turns = len(TURN_RE.findall(out))
    steps = [tuple(map(int, m.groups())) for m in STEP_RE.finditer(out)]
    holds = [int(m.group(1)) for m in HOLDS_RE.finditer(out)]
    content = target.read_text().strip() if target.exists() else None
    return {
        "prompt": prompt,
        "completion": completion,
        "tokens": prompt + completion,
        "turns": turns,
        "steps": steps,
        "final_holds": holds[-1] if holds else None,
        "content": content,
        "ok": content == "alpha",
        "rc": rc,
        "timed_out": timed_out,
    }


def summarise(name: str, runs: list[dict]) -> None:
    if not runs:
        print(f"\n{name}: (no runs)")
        return
    n = len(runs)
    ok = sum(1 for r in runs if r["ok"])
    toks = [r["tokens"] for r in runs]
    turns = [r["turns"] for r in runs]
    print(f"\n{name}")
    print(f"  runs         {n}")
    print(f"  completed    {ok}/{n}  (exp.txt == 'alpha')")
    print(f"  tokens       median {statistics.median(toks):.0f}  "
          f"mean {statistics.mean(toks):.0f}  all {sorted(toks)}")
    print(f"  turns        median {statistics.median(turns):.0f}  all {sorted(turns)}")
    comp = sum(1 for r in runs if r["final_holds"] == 0)
    print(f"  closed       {comp}/{n}  (bridge held 0 at end)")
    if any(r["steps"] for r in runs):
        print(f"  partial      {[r['steps'] for r in runs if r['steps']]}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=3)
    args = ap.parse_args()

    composed_bin = compile_arm(HEADLESS)
    if not ensure_preflip():
        print("FAIL: could not provision the pre-flip control worktree")
        return 1
    oneline_bin = compile_arm(PREFLIP_HEADLESS)
    if composed_bin is None or oneline_bin is None:
        print("FAIL: could not build both arms")
        return 1

    arms = [("composed", composed_bin, HEADLESS), ("one-line", oneline_bin, PREFLIP_HEADLESS)]
    logdir = BENCH / "experiment-logs"
    results: dict[str, list[dict]] = {name: [] for name, _, _ in arms}
    for i in range(args.n):
        for name, binary, directory in arms:
            r = run_once(binary, directory, logdir, name, i + 1)
            results[name].append(r)
            flag = "TIMEOUT" if r["timed_out"] else ("ok " if r["ok"] else "MISS")
            print(f"  run {i + 1} {name:9} tokens={r['tokens']:>6} "
                  f"turns={r['turns']} holds={r['final_holds']} {flag} content={r['content']!r}")

    for name, _, _ in arms:
        summarise(name, results[name])

    c, o = results["composed"], results["one-line"]
    if c and o:
        print("\nverdict")
        print(f"  composed median tokens {statistics.median([r['tokens'] for r in c]):.0f}"
              f"  vs one-line {statistics.median([r['tokens'] for r in o]):.0f}")
        print(f"  composed completed {sum(r['ok'] for r in c)}/{len(c)}"
              f"  vs one-line {sum(r['ok'] for r in o)}/{len(o)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
