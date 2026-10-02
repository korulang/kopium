#!/usr/bin/env python3
"""The bench path goes red if re-dispatch is not deterministic.

Oracle-first mirror of one FrontierHarness Eval v1 scoring property,
Docker-free on the mock gate:

  borrowed oracle : deterministic verifier pass/fail — the v1 scoring
                    rule (MANIFEST.md "The bar") @
                    github.com/frontier-harness-eval/eval @ 8f11b130
                    (2026-09-04): re-verifying the same work yields the
                    same verdict across all 30 tasks. Borrowed flavor:
                    re-dispatching the same invention with the same
                    argument yields the identical verdict. No task code,
                    image, or verifier vendored.
  pattern         : none borrowed from exo — snapshot/rewind, fork, and
                    experiment-history are taken by frontier-001/002/003.
                    This case borrows verifier flavor only.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

One live Bridge: define greet (say) -> dispatch greet(msg: "hi") three
times back-to-back -> all three OK lines must be byte-identical.
Beyond frontier-001 (rewrite changes the body) and frontier-003 (two
names coexist): the SAME name with the SAME argument never wavers.

  python3 bench/frontier/probe_frontier_004.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from gate_session import GateSession

def _vnorm(v: str) -> str:
    """Verdict detail modulo the auto-binding counter — bound=rN
    ticks once per turn by design; the pin is the verdict value."""
    return re.sub(r" bound=r\d+", "", v)

GATE = Path(__file__).parent.parent / "mock-gate-binary"
GREET = "tor greet { msg: string }\ngreet = say(text: msg)"
CALL = 'greet(msg: "hi")'
PIN = "frontier_004_redispatch_determinism"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        dg, ng = s.send(GREET)
        c1, v1 = s.send(CALL)
        c2, v2 = s.send(CALL)
        c3, v3 = s.send(CALL)
    finally:
        s.close()
    print(f"define-greet {dg} {ng}")
    print(f"call-1       {c1} {v1}")
    print(f"call-2       {c2} {v2}")
    print(f"call-3       {c3} {v3}")
    if dg != "DEFINED" or ng != "greet":
        print(f"FAIL: greet did not install — cannot witness {PIN}")
        return 1
    if c1 != "OK" or "text" not in v1:
        print(f"FAIL: first dispatch is not the say verdict — {PIN} unmeasured")
        return 1
    if c2 != "OK" or _vnorm(v2) != _vnorm(v1):
        print(f"FAIL: {PIN} broken — second verdict differs from the first")
        return 1
    if c3 != "OK" or _vnorm(v3) != _vnorm(v1):
        print(f"FAIL: {PIN} broken — third verdict differs from the first")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
