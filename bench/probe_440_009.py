#!/usr/bin/env python3
"""The bench path goes red if 440_009 (run discriminates define) is broken.

Unknown verb is denied; the same `run` then installs a declaration; then
the invention dispatches. `probe_define.py` starts after the install.

  python3 bench/probe_440_009.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"
DECL = "tor greet { msg: string }\ngreet = say(text: msg)"
PIN = "440_009_run_discriminates_define"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        a_st, a_d = s.send('greet(msg: "hi")')
        b_st, b_d = s.send(DECL)
        c_st, c_d = s.send('greet(msg: "hi")')
    finally:
        s.close()
    print(f"A {a_st} {a_d}")
    print(f"B {b_st} {b_d}")
    print(f"C {c_st} {c_d}")
    if a_st != "REJECT" or "greet" not in a_d:
        print(f"FAIL: {PIN} — unknown greet was not denied before define")
        return 1
    if b_st != "DEFINED" or b_d != "greet":
        print(f"FAIL: {PIN} — declaration did not install via run")
        return 1
    if c_st != "OK" or not c_d.startswith("greet"):
        print(f"FAIL: {PIN} — invention did not dispatch after define")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
