#!/usr/bin/env python3
"""The custody record: the resource world a successor can inspect.

SCENE charters "the resource world is a place a successor can inspect:
outstanding holds, how stale, the why of the last possess." This probe runs
`headless/probe_holds.k` — session A mounts a world, lives a clean
open/append/close life, hangs up; session B mounts the same world, mints its
own hold, and reads `holds.log` back through its own `read` verb mid-span —
the record is inspectable through ordinary vocabulary, no special surface.

Needles split across two witnesses: the TRANSCRIPT (B's read reached its
context) and the on-disk LOG (the record the process left behind). Consume-
and-reissue verbs mint per obligation churn, so `append` mints a fresh hold
on the same handle — mint/release pairs are the honest unit.

  python3 bench/probe_holds.py
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_holds.k"
BIN = HEADLESS / "a.out"
WORLD = HEADLESS / "holds-world"
LOG = WORLD / "holds.log"

# What B's `read` saw mid-span: A's complete span plus B's own open mint.
TRANSCRIPT_NEEDLES = [
    ("B read the log through its own vocabulary", "[read] ok: 'holds-world/holds.log'"),
    ("A's mint witnessed with args", "verb=open\ttype=string\tsubject=path=holds-scratch.txt"),
    ("A's session closed", "session-closed\tt="),
    ("B's own mint visible mid-span", "session=sess-b"),
]

# What the record holds after the process is gone.
LOG_NEEDLES = [
    ("A's span opened", "session-open\tt="),
    ("A minted through open", "session=sess-a\thandle="),
    ("A released through close", "release\tt="),
    ("A's span closed", "session-closed"),
    ("B's span opened", "session=sess-b"),
    ("B minted through open", "verb=open"),
    ("teardown closed B too", "session-closed"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    shutil.rmtree(WORLD, ignore_errors=True)
    (HEADLESS / "holds-scratch.txt").unlink(missing_ok=True)
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_holds.k")
        print(r.stdout + r.stderr)
        return 1
    if not BIN.exists():
        print("FAIL: koruc produced no a.out")
        return 1
    r = subprocess.run([str(BIN)], cwd=HEADLESS, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    ok = True
    for label, needle in TRANSCRIPT_NEEDLES:
        if needle in out:
            print(f"PASS  {label}")
        else:
            print(f"FAIL  {label} — missing in transcript: {needle!r}")
            ok = False
    if not LOG.exists():
        print("FAIL  holds.log was never written")
        return 1
    log = LOG.read_text()
    for label, needle in LOG_NEEDLES:
        if needle in log:
            print(f"PASS  {label}")
        else:
            print(f"FAIL  {label} — missing in holds.log: {needle!r}")
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
