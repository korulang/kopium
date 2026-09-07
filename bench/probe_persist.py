#!/usr/bin/env python3
"""Zero-token proof of the harness-join: one process, two lines, same Bridge.

  python3 bench/probe_persist.py

Exit 0 only if mock-gate-binary answers two `say` lines without dying.
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE} — koruc mock-gate.k && cp a.out mock-gate-binary")
        return 1
    s = GateSession(GATE)
    try:
        st1, d1 = s.send('say(text: "a")')
        st2, d2 = s.send('say(text: "b")')
        alive = s.alive
    finally:
        s.close()
    print(f"line1 {st1} {d1}")
    print(f"line2 {st2} {d2}")
    print(f"alive_between {alive}")
    if st1 != "OK" or not d1.startswith("say"):
        print("FAIL: first say was not OK")
        return 1
    if st2 != "OK" or not d2.startswith("say"):
        print("FAIL: second say was not OK — process was one-shot")
        return 1
    if not alive:
        print("FAIL: gate exited after the first line")
        return 1
    print("PASS: one process, two lines, same Bridge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
