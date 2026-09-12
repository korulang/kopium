#!/usr/bin/env python3
"""Zero-token proof: a refusal mid-turn is a step, not a stop.

The wire flip (koru `e2c9bfc9a`, kopium `2f500f3`) made a multi-item turn
sequence under `?partial` — `multiline` pins the green path. This probe pins
the other half of the claim in `koru_std/bridge.run.kz` ("continuing past
refusal: a partial program RUNS, and the model learns every step's outcome"):
a `delete` the notes scope never declared is reported as a `event-denied`
step line, the step after it still runs, and the bridge outlives the turn —
in `headless/probe_partial_denial.k`, canned.

  python3 bench/probe_partial_denial.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_partial_denial.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # the turn is one partial report over all three items
    ("turn reports partial", "partial 3/3"),
    # denial is a named step line, not the turn's verdict
    ("denial is a step line", "step 1/3 event-denied: delete"),
    # the step after a refusal still runs — the turn is not aborted
    ("middle step ran", "step 2/3 result"),
    ("middle verb fired", "middle ran"),
    # a second denial is still just a line
    ("trailing denial a step", "step 3/3 event-denied: delete"),
    # the session outlives it
    ("bridge survives", "still here after two denials"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_partial_denial.k")
        print(r.stdout + r.stderr)
        return 1
    if not BIN.exists():
        print("FAIL: koruc produced no a.out")
        return 1
    r = subprocess.run([str(BIN)], cwd=HEADLESS, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        print("FAIL: probe binary exited nonzero")
        print(out)
        return 1
    failed = 0
    for name, needle in NEEDLES:
        if needle in out:
            print(f"PASS  {name}")
        else:
            print(f"FAIL  {name} — missing {needle!r}")
            failed += 1
    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: a refusal mid-turn is a step line, the turn runs on")
    return 0


if __name__ == "__main__":
    sys.exit(main())
