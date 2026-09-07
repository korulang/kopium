#!/usr/bin/env python3
"""The bench path goes red if the redefine round-trip is broken.

Oracle-first mirror of one FrontierHarness Eval v1 property, Docker-free on
the mock gate:

  borrowed oracle : terminal-bench/git-leak-recovery @
                    github.com/frontier-harness-eval/eval @ 8f11b130
                    (2026-09-04) — its verifier asserts the leaked secret is
                    ABSENT from history after the rewrite. Borrowed flavor:
                    after a rewrite the old body must be GONE. No task code,
                    instruction, image, or verifier vendored.
  pattern         : snapshot -> mutate -> rewind -> assert, borrowed from
                    github.com/exoharness/exo @ 7801005e (2026-09-02).
                    Pattern borrowed, code not.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

Round-trip on one Bridge: define greet v1 (say) -> dispatch (snapshot) ->
redefine greet v2 (mutate) -> dispatch must show v2 with NO v1 residue ->
redefine greet v1 (rewind) -> dispatch must show v1 with NO v2 residue.
Beyond probe_440_012 (which never rewinds): the table holds exactly one
body at a time in both directions.

  python3 bench/frontier/probe_frontier_001.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from gate_session import GateSession

GATE = Path(__file__).parent.parent / "mock-gate-binary"
V1 = "tor greet { msg: string }\ngreet = say(text: msg)"
V2 = (
    "tor greet { msg: string }\n"
    "greet = transfer-to-human-agents(summary: msg)"
)
PIN = "frontier_001_redefine_round_trip"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        d1, n1 = s.send(V1)
        c1, v1 = s.send('greet(msg: "hi")')
        d2, n2 = s.send(V2)
        c2, v2 = s.send('greet(msg: "hi")')
        d3, n3 = s.send(V1)
        c3, v3 = s.send('greet(msg: "hi")')
    finally:
        s.close()
    print(f"define-v1 {d1} {n1}")
    print(f"call-v1   {c1} {v1}")
    print(f"define-v2 {d2} {n2}")
    print(f"call-v2   {c2} {v2}")
    print(f"rewind-v1 {d3} {n3}")
    print(f"call-v1r  {c3} {v3}")
    if d1 != "DEFINED" or n1 != "greet" or c1 != "OK":
        print(f"FAIL: v1 define did not run — cannot witness {PIN}")
        return 1
    if "text" not in v1 or "summary" in v1:
        print(f"FAIL: v1 snapshot is not the say body — {PIN} unmeasured")
        return 1
    if d2 != "DEFINED" or n2 != "greet" or c2 != "OK":
        print(f"FAIL: v2 redefine did not install/dispatch — {PIN}")
        return 1
    if "summary" not in v2 or "text" in v2:
        print(f"FAIL: {PIN} broken — v1 body survived the redefine")
        return 1
    if d3 != "DEFINED" or n3 != "greet" or c3 != "OK":
        print(f"FAIL: rewind redefine did not install/dispatch — {PIN}")
        return 1
    if "text" not in v3 or "summary" in v3:
        print(f"FAIL: {PIN} broken — v2 body survived the rewind")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
