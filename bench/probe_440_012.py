#!/usr/bin/env python3
"""The bench path goes red if 440_012 (redefine replaces the body) is broken.

Mirrors koru tests/regression/.../440_012_redefine_resolves: after a second
define of the same name, dispatch must see the new body, not the stale one.

  python3 bench/probe_440_012.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"
FIRST = "tor greet { msg: string }\ngreet = say(text: msg)"
SECOND = (
    "tor greet { msg: string }\n"
    "greet = transfer-to-human-agents(summary: msg)"
)
PIN = "440_012_redefine_resolves"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        d1, n1 = s.send(FIRST)
        c1, v1 = s.send('greet(msg: "hi")')
        d2, n2 = s.send(SECOND)
        c2, v2 = s.send('greet(msg: "hi")')
    finally:
        s.close()
    print(f"define1 {d1} {n1}")
    print(f"call1   {c1} {v1}")
    print(f"define2 {d2} {n2}")
    print(f"call2   {c2} {v2}")
    if d1 != "DEFINED" or n1 != "greet" or c1 != "OK":
        print(f"FAIL: first define did not run — cannot witness {PIN}")
        return 1
    if "text" not in v1 or "summary" in v1:
        print(f"FAIL: first body (say) did not run — cannot witness {PIN}")
        return 1
    if d2 != "DEFINED" or n2 != "greet":
        print(f"FAIL: redefine did not install — {PIN} unmeasured")
        return 1
    if c2 != "OK":
        print(f"FAIL: greet after redefine did not dispatch — {PIN}")
        return 1
    if "summary" not in v2 or "text" in v2:
        print(f"FAIL: {PIN} broken — second dispatch still ran the old body")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
