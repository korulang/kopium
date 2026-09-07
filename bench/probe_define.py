#!/usr/bin/env python3
"""Zero-token proof: define on the bench path survives the next line.

  python3 bench/probe_define.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"
# Same two-statement source session.k feeds run() on turn 4.
DECL = "tor greet { msg: string }\ngreet = say(text: msg)"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        st1, d1 = s.send(DECL)
        st2, d2 = s.send('greet(msg: "hi")')
        alive = s.alive
    finally:
        s.close()
    print(f"define {st1} {d1}")
    print(f"call   {st2} {d2}")
    print(f"alive  {alive}")
    if st1 != "DEFINED" or d1 != "greet":
        print("FAIL: define did not install greet")
        return 1
    if st2 != "OK" or not d2.startswith("greet"):
        print("FAIL: greet did not dispatch on the same session")
        return 1
    if not alive:
        print("FAIL: gate died between define and call")
        return 1
    print("PASS: define survived the line")
    return 0


if __name__ == "__main__":
    sys.exit(main())
