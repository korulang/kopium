#!/usr/bin/env python3
"""Zero-token proof: the gate's vocabulary is the live Bridge's.

  python3 bench/probe_vocab_live.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"
DECL = "tor greet { msg: string }\ngreet = say(text: msg)"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        before = s.vocabulary()
        st, d = s.send(DECL)
        after = s.vocabulary()
    finally:
        s.close()
    print("before:")
    print(before)
    print(f"define {st} {d}")
    print("after:")
    print(after)
    if "say(" not in before:
        print("FAIL: live vocabulary missing compiled say")
        return 1
    if "greet(" in before:
        print("FAIL: greet present before define — not this session's table")
        return 1
    if st != "DEFINED" or d != "greet":
        print("FAIL: define did not install greet")
        return 1
    if "greet(" not in after:
        print("FAIL: live vocabulary missing invented greet")
        return 1
    print("PASS: prompt vocabulary is the same Bridge that defined greet")
    return 0


if __name__ == "__main__":
    sys.exit(main())
