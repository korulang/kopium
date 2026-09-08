#!/usr/bin/env python3
"""The bench path goes red if a fresh session is not a fresh restore.

Oracle-first mirror of one FrontierHarness Eval v1 harness property,
Docker-free on the mock gate:

  borrowed oracle : the golden-checkpoint -> fresh-restore-per-task
                    protocol @ github.com/frontier-harness-eval/eval @
                    8f11b130 (2026-09-04) — every task starts from
                    identical state, no cross-task contamination.
                    Borrowed flavor: a fresh Bridge starts identical
                    and clean — no task code, image, or verifier
                    vendored.
  pattern         : fork, borrowed from github.com/exoharness/exo @
                    7801005e (2026-09-02). Two live sessions diverge
                    from the same start and each keeps its own body.
                    Pattern borrowed, code not.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

Two live Bridges on one binary: A defines greet v1 (say) -> fresh B
must REJECT greet, and greet must be absent from B's vocabulary and
grammar -> B defines greet v2 (fork) -> B dispatches v2 while A still
dispatches v1. Beyond probe_vocab_live (one session's before/after):
inventions never cross the session seam in either direction.

  python3 bench/frontier/probe_frontier_002.py
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
CALL = 'greet(msg: "hi")'
RULE = "one invocation per line"
PIN = "frontier_002_fresh_restore"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    a = GateSession(GATE)
    b: GateSession | None = None
    try:
        da, na = a.send(V1)
        ca, va = a.send(CALL)
        vocab_a = a.vocabulary()
        b = GateSession(GATE)
        cb, vb = b.send(CALL)
        vocab_b = b.vocabulary()
        grammar_b = b.grammar()
        db, nb = b.send(V2)
        cb2, vb2 = b.send(CALL)
        ca2, va2 = a.send(CALL)
    finally:
        if b is not None:
            b.close()
        a.close()
    print(f"A define-v1 {da} {na}")
    print(f"A call-v1   {ca} {va}")
    print(f"B fresh-call {cb} {vb}")
    print(f"B define-v2 {db} {nb}")
    print(f"B call-v2   {cb2} {vb2}")
    print(f"A call-v1r  {ca2} {va2}")
    if da != "DEFINED" or na != "greet" or ca != "OK":
        print(f"FAIL: A did not install v1 — cannot witness {PIN}")
        return 1
    if "text" not in va or "summary" in va:
        print(f"FAIL: A v1 snapshot is not the say body — {PIN} unmeasured")
        return 1
    if "greet(" not in vocab_a:
        print(f"FAIL: A vocabulary missing its own invention — {PIN} unmeasured")
        return 1
    if cb != "REJECT" or "greet" not in vb:
        print(f"FAIL: {PIN} broken — fresh B did not refuse A's invention")
        return 1
    if "greet(" in vocab_b:
        print(f"FAIL: {PIN} broken — A's invention leaked into B's vocabulary")
        return 1
    if "greet(" in grammar_b or RULE not in grammar_b:
        print(f"FAIL: {PIN} broken — B's grammar is not the clean render")
        return 1
    if db != "DEFINED" or nb != "greet" or cb2 != "OK":
        print(f"FAIL: B fork did not install/dispatch — {PIN}")
        return 1
    if "summary" not in vb2 or "text" in vb2:
        print(f"FAIL: {PIN} broken — B fork still ran A's body")
        return 1
    if ca2 != "OK" or "text" not in va2 or "summary" in va2:
        print(f"FAIL: {PIN} broken — B's fork contaminated live A")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
