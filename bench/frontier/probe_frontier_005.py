#!/usr/bin/env python3
"""The bench path goes red if the wire gate stops refusing non-wire turns.

Oracle-first mirror of one BFCL scoring property, Docker-free on the
mock gate:

  borrowed oracle : BFCL Simple (AST) — "one and only one function call
                    being invoked" @ github.com/ShishirPatil/gorilla @
                    6ea57973 (main HEAD, 2026-03-23). BFCL scores at eval
                    time what the bridge enforces at parse time: anything
                    but exactly one complete invocation fails. No task
                    code, data, or verifier vendored.
  pattern         : none borrowed from exo — snapshot/rewind, fork, and
                    experiment-history are taken by frontier-001/002/003,
                    verifier flavor by frontier-004. This case borrows
                    AST-scoring flavor only.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

One live Bridge, all canned lines, zero model tokens: prose, trailing
text, a chained second call, and a truncated string must each REJECT
with a model-directed diagnostic — and the session must still dispatch
a clean invocation afterward (refusals never poison the Bridge).
Beyond probe_440_009 (an unknown VERB is denied): these turns never
reach dispatch at all — the parse gate refuses the SHAPE.

  python3 bench/frontier/probe_frontier_005.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from gate_session import GateSession

GATE = Path(__file__).parent.parent / "mock-gate-binary"
PROSE = "hello there please say hi"
TRAILING = 'say(text: "hi") trailing garbage'
CHAIN = 'say(text: "a") say(text: "b")'
TRUNCATED = 'say(text: "hi)'
LEGIT = 'say(text: "hi")'
PIN = "frontier_005_one_invocation_wire_gate"


def main() -> int:
    if not GATE.exists():
        print(f"FAIL: missing {GATE}")
        return 1
    s = GateSession(GATE)
    try:
        st_prose, d_prose = s.send(PROSE)
        st_trail, d_trail = s.send(TRAILING)
        st_chain, d_chain = s.send(CHAIN)
        st_trunc, d_trunc = s.send(TRUNCATED)
        st_ok, d_ok = s.send(LEGIT)
    finally:
        s.close()
    print(f"prose     {st_prose} {d_prose}")
    print(f"trailing  {st_trail} {d_trail}")
    print(f"chain     {st_chain} {d_chain}")
    print(f"truncated {st_trunc} {d_trunc}")
    print(f"legit     {st_ok} {d_ok}")
    if st_prose != "REJECT" or "not wire" not in d_prose:
        print(f"FAIL: {PIN} broken — prose passed the wire gate")
        return 1
    if st_trail != "REJECT" or "nothing follows" not in d_trail:
        print(f"FAIL: {PIN} broken — trailing text passed the wire gate")
        return 1
    if st_chain != "REJECT" or "nothing follows" not in d_chain:
        print(f"FAIL: {PIN} broken — a chained second call passed the wire gate")
        return 1
    if st_trunc != "REJECT" or "truncated" not in d_trunc:
        print(f"FAIL: {PIN} broken — a truncated string passed the wire gate")
        return 1
    if st_ok != "OK" or not d_ok.startswith("say"):
        print(f"FAIL: {PIN} broken — refusals poisoned the session")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
