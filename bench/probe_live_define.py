#!/usr/bin/env python3
"""Zero-token proof: a define completes on the LIVE drive path, canned.

The bench intake (`gate_intake.kz`) already preserves two-line declarations.
`headless/live.k` drive did not: `wire:clean` kept the first line, so a
define never arrived whole. This probe drives the scripted declaration
through the live intake itself — `app/wire:clean` + `std/bridge:run` in
`headless/probe_live_define.k`, the same two tors `live.k` drive calls —
and asserts the whole loop: discovered from the prompt, arrived whole,
installed, redispatched, rendered.

  python3 bench/probe_live_define.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_live_define.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # 1. discoverable — the prompt names the two-line shape
    ("prompt names the shape", "A definition is the one reply"),
    ("prompt shows the example", "tor greet { msg: string }"),
    # 2. arrives whole through wire:clean (not first-line-truncated)
    ("intake keeps both lines", "cleaned> tor greet { msg: string }\ngreet = say(text: msg)"),
    # 3. installs
    ("run installs", "DEFINED greet"),
    # 4. redispatches next turn
    ("invention dispatches", "greet ran"),
    # 5+6. derived renders include the invention
    ("vocabulary lists greet", "greet(msg: string)"),
    # 7. the flip — clean keeps the whole turn, no head truncation
    ("contrast keeps the turn", 'kept: [open(path: "a")\nclose(handle: "deadbe")]'),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_live_define.k")
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
    print("PASS: live define completes on the live drive path, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
