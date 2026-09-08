#!/usr/bin/env python3
"""Zero-token proof: the notes bridge can read the disk through `read`.

The forcing (vulcan-forcing 2026-09-07): py-expr-eval needs file-read — the
bridge cannot see code it cannot open. This probe drives a scripted `read`
through `std/bridge:run` in `headless/probe_notes_read.k`, the same dispatch
`session.k` turns and `live.k` drive call — and asserts the whole loop: the
task file's bytes arrive on the transcript, a missing file reports
not-found without killing the bridge, the old verbs still run after the
miss, the derived vocabulary lists `read`, and an undeclared verb is still
denied (smallest wall kept).

  python3 bench/probe_notes_read.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_notes_read.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # 1. the vulcan attempt: the task file's bytes reach the transcript
    ("attempt shows the task file", "2 + 3 * 4"),
    ("run reports ok", "[read] ok: 'probe_task_expr.txt'"),
    ("result arm, nothing minted", "read ran \u2014 bridge holds 0 resource(s), nothing minted"),
    # 2. absence hands back (430_056): ok handled, missing fired, the bridge
    # returned it as unhandled-branch — it does not refuse or crash
    ("missing reports not-found", "[read] not-found: 'no-such-file.txt'"),
    ("miss hands back", "UNHANDLED branch=[missing]"),
    # 3. the session outlives the miss
    ("bridge survives", "still here after not-found"),
    # 4. the derived vocabulary includes read
    ("vocabulary lists read", "read(path: string)"),
    # 5. the wall did not move
    ("contrast denies delete", "DENIED delete"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_notes_read.k")
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
    print("PASS: read opens disk files to the bridge, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
