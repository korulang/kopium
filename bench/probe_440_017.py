#!/usr/bin/env python3
"""The bench path goes red if 440_017 (grammar = rules + inventions) is broken.

  python3 bench/probe_440_017.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from gate_session import GateSession

GATE = Path(__file__).parent / "mock-gate-binary"
DECL = "tor greet { msg: string }\ngreet = say(text: msg)"
PIN = "440_017_bridge_grammar_renders_rules_and_inventions"
RULE = "one invocation per line"
VOCAB_HDR = "Your vocabulary:"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        before = s.grammar()
        st, d = s.send(DECL)
        after = s.grammar()
        vocab = s.vocabulary()
    finally:
        s.close()
    print("before grammar:")
    print(before)
    print(f"define {st} {d}")
    print("after grammar:")
    print(after)
    if RULE not in before or VOCAB_HDR not in before:
        print(f"FAIL: {PIN} — grammar is not the wire+vocab render")
        return 1
    if "say(" not in before:
        print(f"FAIL: {PIN} — compiled say missing from grammar")
        return 1
    if "greet(" in before:
        print("FAIL: greet in grammar before define — not this session")
        return 1
    if st != "DEFINED" or d != "greet":
        print("FAIL: define did not install greet")
        return 1
    if RULE not in after or "greet(" not in after:
        print(f"FAIL: {PIN} broken — grammar after define lacks rules or greet")
        return 1
    if RULE in vocab:
        print(f"FAIL: {PIN} unmeasured — vocabulary() is not grammar()")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
