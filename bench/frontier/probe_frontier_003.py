#!/usr/bin/env python3
"""The bench path goes red if inventions do not accumulate.

Oracle-first mirror of one harness property, Docker-free on the mock gate:

  borrowed oracle : the experiment-history flavor — every trial retained,
                    none evicted. FrontierHarness Eval v1 keeps all 360
                    evaluations (30 tasks x 12 configs) in
                    results/eval-data.json @
                    github.com/frontier-harness-eval/eval @ 8f11b130
                    (2026-09-04); pattern borrowed from
                    github.com/exoharness/exo @ 7801005e (2026-09-02)
                    (experiment history). No task code, image, or
                    verifier vendored.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

One live Bridge: define greet (say) -> dispatch -> define farewell
(transfer-to-human-agents) -> dispatch -> greet must STILL dispatch
its own body, and both names must render in vocabulary() and
grammar(). Beyond frontier-001 (one name rewritten and rewound) and
frontier-002 (nothing crosses the session seam): two distinct names
coexist in one session's table.

  python3 bench/frontier/probe_frontier_003.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from gate_session import GateSession

GATE = Path(__file__).parent.parent / "mock-gate-binary"
GREET = "tor greet { msg: string }\ngreet = say(text: msg)"
FAREWELL = (
    "tor farewell { msg: string }\n"
    "farewell = transfer-to-human-agents(summary: msg)"
)
CALL_GREET = 'greet(msg: "hi")'
CALL_FAREWELL = 'farewell(msg: "bye")'
RULE = "one invocation per line"
PIN = "frontier_003_inventions_accumulate"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        dg, ng = s.send(GREET)
        cg, vg = s.send(CALL_GREET)
        df, nf = s.send(FAREWELL)
        cf, vf = s.send(CALL_FAREWELL)
        cg2, vg2 = s.send(CALL_GREET)
        vocab = s.vocabulary()
        grammar = s.grammar()
    finally:
        s.close()
    print(f"define-greet    {dg} {ng}")
    print(f"call-greet      {cg} {vg}")
    print(f"define-farewell {df} {nf}")
    print(f"call-farewell   {cf} {vf}")
    print(f"call-greet-again {cg2} {vg2}")
    if dg != "DEFINED" or ng != "greet" or cg != "OK":
        print(f"FAIL: greet did not install/dispatch — cannot witness {PIN}")
        return 1
    if "text" not in vg or "summary" in vg:
        print(f"FAIL: greet snapshot is not the say body — {PIN} unmeasured")
        return 1
    if df != "DEFINED" or nf != "farewell" or cf != "OK":
        print(f"FAIL: farewell did not install/dispatch — {PIN}")
        return 1
    if "summary" not in vf or "text" in vf:
        print(f"FAIL: {PIN} broken — farewell ran greet's body")
        return 1
    if cg2 != "OK" or "text" not in vg2 or "summary" in vg2:
        print(f"FAIL: {PIN} broken — defining farewell evicted greet")
        return 1
    if "greet(" not in vocab or "farewell(" not in vocab:
        print(f"FAIL: {PIN} broken — vocabulary lost an invention")
        return 1
    if RULE not in grammar or "greet(" not in grammar or "farewell(" not in grammar:
        print(f"FAIL: {PIN} broken — grammar lost rules or an invention")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
