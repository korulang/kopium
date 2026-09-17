#!/usr/bin/env python3
"""The frag-partial-programs experiment: composition vs the one-line law.

The fragment is explicit — "identical goals, multi-invocation turns vs the
one-line law, cost-per-task and reliability vote" — and guilty until measured
innocent. This drives one chained task (open → write → close) through three
arms:

  composed   — `headless/experiment.k` on the current intake (the whole turn
               reaches `std/bridge:run`, which sequences it)
  one-line   — the SAME program from a pre-flip worktree (the intake that
               truncated to the head and enforced one invocation per turn —
               but a single-line chain still parses under the modern wire)
  pre-chain  — kopium at the commit contemporaneous with koru 70aeb093a~1,
               compiled by that era's koruc: parse.wire refuses `|>` outright,
               so a chain is a parse-error the model is told about, and the
               handle must be carried as a literal string across turns

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

# The true pre-chain control: kopium at the commit contemporaneous with koru
# 70aeb093a~1 ("wire takes chains"'s parent), compiled by THAT era's koruc so
# parse.wire genuinely refuses `|>` — not an intake truncation but a parse
# rejection ("chains are not wire: one invocation per turn").
PRECHAIN = Path.home() / "src" / "kopium-prechain"
PRECHAIN_HEADLESS = PRECHAIN / "headless"
PRECHAIN_REF = "d7e5c3b"  # kopium contemporaneous with koru 70aeb093a~1
PRECHAIN_KORUC = Path.home() / "src" / "koru-prechain" / "zig-out" / "bin" / "koruc"
PRECHAIN_KORU_REF = "511392414"  # koru 70aeb093a~1 — parse.wire refuses chains

USAGE_RE = re.compile(r"\[usage\] prompt (\d+) completion (\d+)")
TURN_RE = re.compile(r"^turn \d+", re.MULTILINE)
HOLDS_RE = re.compile(r"bridge (?:now )?holds (\d+)")
STEP_RE = re.compile(r"steps: (\d+)/(\d+) ran")
CHECK_RE = re.compile(r"turn-check (\d+): \[(.*?)\]", re.DOTALL)

# Era adaptation: pre-chain `std/bridge:run` has no `unhandled-branch` arm —
# the branch did not exist until the chain rung. Dropping it is not weakening
# the experiment: the era's run cannot emit it. If the arm's text moves, this
# stops matching and we fail loud rather than silently run a stale source.
UNHANDLED_ARM_RE = re.compile(r"\| unhandled-branch ub[^\n]*\n(?:\s+\|>[^\n]*\n)*")


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


def ensure_prechain() -> bool:
    """The pre-chain arm: kopium at PRECHAIN_REF, compiled by the pre-chain
    koruc so the wire itself refuses `|>`. experiment.k is the same file minus
    the `unhandled-branch` arm the era's run cannot produce."""
    if not PRECHAIN_HEADLESS.exists():
        r = subprocess.run(["git", "worktree", "add", str(PRECHAIN), PRECHAIN_REF],
                           cwd=REPO, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr)
            return False
    if not PRECHAIN_KORUC.exists():
        print(f"  ! pre-chain koruc missing: {PRECHAIN_KORUC}")
        print(f"    expected a worktree of koru at {PRECHAIN_KORU_REF}, built with `zig build`")
        return False
    head = subprocess.run(["git", "rev-parse", "--short=9", "HEAD"],
                          cwd=Path.home() / "src" / "koru-prechain",
                          capture_output=True, text=True).stdout.strip()
    if head != PRECHAIN_KORU_REF:
        print(f"  ! koru-prechain is at {head}, expected {PRECHAIN_KORU_REF}")
        return False
    src = (HEADLESS / "experiment.k").read_text()
    adapted = UNHANDLED_ARM_RE.sub("", src, count=1)
    if adapted == src:
        print("  ! unhandled-branch arm not found in experiment.k — the era adaptation needs revisiting")
        return False
    (PRECHAIN_HEADLESS / "experiment.k").write_text(adapted)
    return True


def compile_arm(directory: Path, koruc: str = "koruc") -> Path | None:
    src = directory / "experiment.k"
    if not src.exists():
        print(f"  ! {src} missing")
        return None
    r = subprocess.run([koruc, "experiment.k"], cwd=directory, capture_output=True, text=True)
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
    usages = [(int(m.group(1)), int(m.group(2))) for m in USAGE_RE.finditer(out)]
    prompt = sum(p for p, _ in usages)
    completion = sum(c for _, c in usages)
    turns = len(TURN_RE.findall(out))
    steps = [tuple(map(int, m.groups())) for m in STEP_RE.finditer(out)]
    holds = [int(m.group(1)) for m in HOLDS_RE.finditer(out)]
    content = target.read_text().strip() if target.exists() else None

    # Cost-to-completion: sum usage through the first turn whose file check
    # shows the task's bytes. `None` (censored) if the task never completed.
    checks = [(int(m.group(1)), m.group(2)) for m in CHECK_RE.finditer(out)]
    done_turn = next((t for t, c in checks if "alpha" in c), None)
    cost_to_complete = sum(p + c for p, c in usages[:done_turn]) if done_turn else None

    # Strict completion: bytes right AND the bridge holding nothing at that
    # turn-check. Without it a run that writes 'alpha' but leaves the note
    # open counts as done at the write turn — systematically flattering arms
    # that can't close in the same turn.
    hold_events = [(m.start(), int(m.group(1))) for m in HOLDS_RE.finditer(out)]
    strict_turn = None
    for t, c in checks:
        if "alpha" not in c:
            continue
        check_pos = out.find(f"turn-check {t}:")
        held = next((h for pos, h in reversed(hold_events) if pos < check_pos), None)
        if held == 0:
            strict_turn = t
            break
    strict_ctc = sum(p + c for p, c in usages[:strict_turn]) if strict_turn else None

    return {
        "prompt": prompt,
        "completion": completion,
        "tokens": prompt + completion,
        "turns": turns,
        "steps": steps,
        "final_holds": holds[-1] if holds else None,
        "content": content,
        "ok": content == "alpha",
        "done_turn": done_turn,
        "cost_to_complete": cost_to_complete,
        "strict_turn": strict_turn,
        "strict_ctc": strict_ctc,
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
    ctc = [r["cost_to_complete"] for r in runs if r["cost_to_complete"] is not None]
    sctc = [r["strict_ctc"] for r in runs if r["strict_ctc"] is not None]
    print(f"\n{name}")
    print(f"  runs         {n}")
    print(f"  completed    {ok}/{n}  (exp.txt == 'alpha')")
    print(f"  cost-to-comp {len(ctc)}/{n} reached by file check", end="")
    if ctc:
        print(f"  median {statistics.median(ctc):.0f}  all {sorted(ctc)}")
    else:
        print()
    print(f"  strict ctc   {len(sctc)}/{n} bytes-right AND holds-0", end="")
    if sctc:
        print(f"  median {statistics.median(sctc):.0f}  all {sorted(sctc)}")
    else:
        print()
    print(f"  full window  median {statistics.median(toks):.0f}  "
          f"mean {statistics.mean(toks):.0f}  all {sorted(toks)}")
    print(f"  turns        median {statistics.median(turns):.0f}  all {sorted(turns)}")
    comp = sum(1 for r in runs if r["final_holds"] == 0)
    print(f"  closed       {comp}/{n}  (bridge held 0 at end)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=3)
    args = ap.parse_args()

    composed_bin = compile_arm(HEADLESS)
    if not ensure_preflip():
        print("FAIL: could not provision the pre-flip control worktree")
        return 1
    oneline_bin = compile_arm(PREFLIP_HEADLESS)
    if not ensure_prechain():
        print("FAIL: could not provision the pre-chain control worktree")
        return 1
    prechain_bin = compile_arm(PRECHAIN_HEADLESS, str(PRECHAIN_KORUC))
    if composed_bin is None or oneline_bin is None or prechain_bin is None:
        print("FAIL: could not build all three arms")
        return 1

    arms = [("composed", composed_bin, HEADLESS), ("one-line", oneline_bin, PREFLIP_HEADLESS),
            ("pre-chain", prechain_bin, PRECHAIN_HEADLESS)]
    logdir = BENCH / "experiment-logs"
    results: dict[str, list[dict]] = {name: [] for name, _, _ in arms}
    for i in range(args.n):
        for name, binary, directory in arms:
            r = run_once(binary, directory, logdir, name, i + 1)
            results[name].append(r)
            flag = "TIMEOUT" if r["timed_out"] else ("ok " if r["ok"] else "MISS")
            print(f"  run {i + 1} {name:9} tokens={r['tokens']:>6} "
                  f"ctc={r['cost_to_complete']} done@={r['done_turn']} "
                  f"holds={r['final_holds']} {flag}")

    for name, _, _ in arms:
        summarise(name, results[name])

    def med(vals):
        vals = [v for v in vals if v is not None]
        return statistics.median(vals) if vals else None

    print("\nverdict — cost-to-completion (tokens through the first passing file check)")
    for name, _, _ in arms:
        runs = results[name]
        if not runs:
            continue
        timeouts = sum(r["timed_out"] for r in runs)
        print(f"  {name:9} ctc {med([r['cost_to_complete'] for r in runs])}  "
              f"strict {med([r['strict_ctc'] for r in runs])}  "
              f"completed {sum(r['ok'] for r in runs)}/{len(runs)}  "
              f"timeouts {timeouts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
