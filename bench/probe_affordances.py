#!/usr/bin/env python3
"""Zero-token proof: the possession-shaped callable surface (HATEOAS rooms).

`std/bridge:affordances` answers "given what I hold, what can I call now?"
— the scope's static vocabulary filtered by the live handle pool. The notes
scope declares two possession-gated verbs (`append`, `close` consume
`<!open>`) and four always-callable ones; the surface must shrink and grow
with the bridge:

  A  nothing held -> open/read/edit/say only, append/close absent
  B  open a note -> you hold: note_0(open); append/close appear
  C  close it -> append/close vanish again

  python3 bench/probe_affordances.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_affordances.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # A: nothing held — the always-callable surface
    ("A names the empty state", "you hold: nothing"),
    ("A lists always-callable open", "open(path: string)"),
    ("A lists say", "say(text: string)"),
    # B: possession grows the surface
    ("B names the held handle", "you hold: note_0(open)"),
    ("B gates append in", "append(handle: string<!open>, text: string)"),
    ("B gates close in", "close(handle: string<!open>)"),
    # C: release shrinks it back
    ("C returns to nothing held", "you hold: nothing"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_affordances.k")
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
    # The possession gate itself: append appears exactly once (B), so the
    # empty and closed renders never offered it.
    gated = out.count("append(handle: string<!open>, text: string)")
    if gated != 1:
        print(f"FAIL  append visible {gated} times \u2014 want exactly 1 (only while holding open)")
        failed += 1
    else:
        print("PASS  append gated to possession (1 render only)")
    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: the callable surface is possession-shaped, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
