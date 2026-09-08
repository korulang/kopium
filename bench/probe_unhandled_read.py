#!/usr/bin/env python3
"""Zero-token proof: the unhandled-branch hand-back fires on the notes bridge.

430_056 ruling: a fragment that does not handle an outcome hands it back as
`unhandled-branch` instead of erroring. The notes scope used to have NO
named-branch verb, so nothing a model could emit produced a hand-back — the
baton session measured zero named branches across 6 live turns. `read` now
returns `| ok | missing path`, and this probe drives the four shapes through
the same `std/bridge:run` (lenient by default) that `live.k`'s `act` calls:
bare-read-missing hands back, partial-handling hands back, bare-read-existing
hands back the ok branch (bytes still arrive), and a handled ok completes.

  python3 bench/probe_unhandled_read.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_unhandled_read.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # A: the live single-line shape — bare read of an absent path hands back
    ("A bare read hands back", "A-UNHANDLED branch=[missing]"),
    ("A payload names the path", '"value":"no-such-file.txt"'),
    # B: the ruling's canonical partial-fragment shape hands back
    ("B partial hands back", "B-UNHANDLED branch=[missing]"),
    # C: bare read of an existing file hands back the ok branch too
    ("C bare ok hands back", "C-UNHANDLED branch=[ok]"),
    ("C bytes still arrive", "the fixture exists"),
    # D: a handled ok completes as result (control)
    ("D handled ok completes", "D-RESULT branch=[]"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_unhandled_read.k")
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
            print(f"FAIL  {name} \u2014 missing {needle!r}")
            failed += 1
    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: the hand-back is witnessed, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
