#!/usr/bin/env python3
"""Zero-token proof: define a verb and USE it in the same turn.

Under the old wire, a `tor ` declaration was its own turn and a second
invocation was truncated, so define→use always cost two turns. The sequencing
path shares the session's defined table across items (koru `e2c9bfc9a`), so a
define item followed by a dispatch item runs and reports as one turn. This
probe drives the shape through the live intake (`app/wire:clean` +
`std/bridge:run`) in `headless/probe_define_use.k`, canned.

  python3 bench/probe_define_use.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_define_use.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # the turn is two items, not one
    ("two items reported", "PARTIAL 2/2"),
    # the define installed
    ("define installed as a step", "step 1/2 defined: greet"),
    # the call after it ran (not denied — the defined table carried across items)
    ("call after define ran", "step 2/2 result"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_define_use.k")
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
    # the defined verb actually spoke
    if "hello from the same turn" not in out:
        print("FAIL  the defined verb did not run")
        failed += 1
    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: define and use in one turn")
    return 0


if __name__ == "__main__":
    sys.exit(main())
