#!/usr/bin/env python3
"""Zero-token proof: a multi-item turn sequences on the live drive path.

The old wire truncated a reply to its head (`wire:clean`) and reported the
drop (`extra-lines`); a second invocation could never reach the bridge. The
toolchain now sequences multi-item turns (`std/bridge:run`, koru
`e2c9bfc9a`), and this probe drives the equal-and-opposite intake — whole turn
through `app/wire:clean`, then `std/bridge:run` — in
`headless/probe_multiline.k`, canned. It asserts the whole turn survives
clean and the bridge reports one line per step under `partial`.

  python3 bench/probe_multiline.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_multiline.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # clean keeps the whole turn — not the head
    ("clean keeps both lines", 'clean kept: [say(text: "one")\nsay(text: "two")]'),
    # the bridge sequences it and reports per step
    ("bridge sequences", "partial 2/2"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_multiline.k")
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
    print("PASS: a multi-item turn sequences on the live drive path, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
