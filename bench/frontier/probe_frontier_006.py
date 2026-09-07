#!/usr/bin/env python3
"""The bench path goes red if a defined invention drops the caller's arguments.

Oracle-first mirror of one BFCL scoring property, Docker-free on the
mock gate:

  borrowed oracle : BFCL AST scoring — the emitted call matches not just
                    the function name but its argument VALUES @
                    github.com/ShishirPatil/gorilla @ 6ea57973 (main
                    HEAD, 2026-03-23). Borrowed flavor: dispatching one
                    defined invention with different arguments must carry
                    each call's own values into the body. No task code,
                    data, or verifier vendored.
  pattern         : none borrowed from exo — snapshot/rewind, fork, and
                    experiment-history are taken by frontier-001/002/003,
                    verifier flavor by frontier-004, the count half of
                    the AST rule ("one and only one function call") by
                    frontier-005. This case borrows the value half only.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

One live Bridge, all canned lines, zero model tokens: define greet
(say) -> greet(msg: "hi") must echo hi -> greet(msg: "bye") must
echo bye with no hi residue -> greet(msg: "hi") again must be
byte-identical to the first hi. Beyond frontier-004 (the SAME
argument never wavers): DIFFERENT arguments never collide — the
detail tracks the caller, not the definition.

  python3 bench/frontier/probe_frontier_006.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from gate_session import GateSession

GATE = Path(__file__).parent.parent / "mock-gate-binary"
GREET = "tor greet { msg: string }\ngreet = say(text: msg)"
HI = 'greet(msg: "hi")'
BYE = 'greet(msg: "bye")'
PIN = "frontier_006_argument_fidelity"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        dg, ng = s.send(GREET)
        c1, v1 = s.send(HI)
        c2, v2 = s.send(BYE)
        c3, v3 = s.send(HI)
    finally:
        s.close()
    print(f"define-greet {dg} {ng}")
    print(f"call-hi      {c1} {v1}")
    print(f"call-bye     {c2} {v2}")
    print(f"call-hi-again {c3} {v3}")
    if dg != "DEFINED" or ng != "greet":
        print(f"FAIL: greet did not install — cannot witness {PIN}")
        return 1
    if c1 != "OK" or "hi" not in v1 or "bye" in v1 or "text" not in v1:
        print(f"FAIL: hi dispatch did not carry hi — {PIN} unmeasured")
        return 1
    if c2 != "OK" or "bye" not in v2 or "hi" in v2:
        print(f"FAIL: {PIN} broken — bye dispatch kept hi residue")
        return 1
    if c3 != "OK" or v3 != v1:
        print(f"FAIL: {PIN} broken — same argument re-dispatched a different detail")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
