#!/usr/bin/env python3
"""THE RULING, encoded as a test (Lars 2026-09-07/08): handles are OPAQUE.

A freshly minted handle is 6 lowercase hex, not `note_N`, not sequential,
not guessable. The only legal access is binding what an observation
returned; a fabricated name is refused. This probe asserts all five:

  A  first open -> minted-1 is 6 lowercase hex, not "note_"
  B  second open -> minted-2 differs (nothing sequential to predict)
  C  append with the minted handle -> binds
  D  close with the minted handle -> binds
  E  a fabricated 6-hex guess -> refused

  python3 bench/probe_opaque_handles.py
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_opaque_handles.k"
BIN = HEADLESS / "a.out"

HEX6 = re.compile(r"^[0-9a-f]{6}$")


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_opaque_handles.k")
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
    m1 = re.search(r"minted-1: (\S+)", out)
    m2 = re.search(r"minted-2: (\S+)", out)

    # A: opaque shape — 6 lowercase hex, not the domain name
    if not m1:
        print("FAIL  minted-1 not printed")
        failed += 1
    elif not HEX6.match(m1.group(1)):
        print(f"FAIL  minted-1 {m1.group(1)!r} is not 6 lowercase hex (the ruling)")
        failed += 1
    else:
        print(f"PASS  minted-1 is opaque ({m1.group(1)})")
    if m1 and "note_" in m1.group(1):
        print(f"FAIL  minted-1 still domain-named: {m1.group(1)!r}")
        failed += 1
    elif m1:
        print("PASS  minted-1 is not domain-named")

    # B: two mints differ — nothing sequential to predict
    if not m2:
        print("FAIL  minted-2 not printed")
        failed += 1
    elif not HEX6.match(m2.group(1)):
        print(f"FAIL  minted-2 {m2.group(1)!r} is not 6 lowercase hex (the ruling)")
        failed += 1
    else:
        print(f"PASS  minted-2 is opaque ({m2.group(1)})")
    if m1 and m2 and m1.group(1) == m2.group(1):
        print(f"FAIL  both mints identical {m1.group(1)!r} — nothing to predict, but also nothing to bind to")
        failed += 1
    elif m1 and m2:
        print("PASS  two mints differ")

    # C/D: the minted handle binds
    if "append-bound: ok" in out:
        print("PASS  append binds with the minted handle")
    else:
        print("FAIL  append did not bind with the minted handle")
        failed += 1
    if "close-bound: ok" in out:
        print("PASS  close binds with the same handle")
    else:
        print("FAIL  close did not bind with the minted handle")
        failed += 1

    # E: a fabricated guess is refused
    if "refused:" in out:
        print("PASS  fabricated handle refused")
    else:
        print("FAIL  fabricated handle was not refused")
        failed += 1

    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: THE RULING HOLDS — handles are opaque, binding-only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
