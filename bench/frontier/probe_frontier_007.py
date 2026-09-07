#!/usr/bin/env python3
"""The bench path goes red if an unrelated define perturbs a live neighbor.

Oracle-first mirror of one DeepSWE scoring property, Docker-free on the
mock gate:

  borrowed oracle : DeepSWE post-patch regression — the v1 bar's 9
                    datacurve-ai/deep-swe (v1.1) tasks re-run the repo's
                    EXISTING tests after the patch lands @
                    github.com/frontier-harness-eval/eval @ 8f11b130
                    (2026-09-04): a passing test that predates the patch
                    must still pass byte-for-byte afterward. Borrowed
                    flavor: a neighbor invention's verdict must be
                    byte-identical before and after an unrelated define.
                    No task code, image, or verifier vendored.
  pattern         : none borrowed from exo — snapshot/rewind, fork, and
                    experiment-history are taken by frontier-001/002/003,
                    verifier flavor by frontier-004, the count half of
                    the BFCL AST rule by frontier-005, the value half by
                    frontier-006. This case borrows DeepSWE regression
                    flavor only.
  closer          : this file's exit code via bench/harness-check.py.
  date            : 2026-09-05.

One live Bridge, all canned lines, zero model tokens: define greet
(say) -> snapshot its OK line -> define farewell
(transfer-to-human-agents, the unrelated patch) -> farewell must
dispatch its own body (the patch genuinely landed) -> greet must
re-dispatch the byte-identical OK line. Beyond frontier-003 (both
names stay dispatchable): the neighbor's VERDICT never wavers — an
unrelated define is observable nowhere in the old verdict's bytes.

  python3 bench/frontier/probe_frontier_007.py
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
PIN = "frontier_007_neighbor_verdict_stability"


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
    finally:
        s.close()
    print(f"define-greet    {dg} {ng}")
    print(f"call-greet      {cg} {vg}")
    print(f"define-farewell {df} {nf}")
    print(f"call-farewell   {cf} {vf}")
    print(f"call-greet-after {cg2} {vg2}")
    if dg != "DEFINED" or ng != "greet" or cg != "OK":
        print(f"FAIL: greet did not install/dispatch — cannot witness {PIN}")
        return 1
    if "text" not in vg or "hi" not in vg:
        print(f"FAIL: greet snapshot is not the say verdict — {PIN} unmeasured")
        return 1
    if df != "DEFINED" or nf != "farewell" or cf != "OK":
        print(f"FAIL: farewell patch did not install/dispatch — {PIN}")
        return 1
    if "summary" not in vf or "bye" not in vf or "text" in vf:
        print(f"FAIL: {PIN} unmeasured — farewell did not run its own body")
        return 1
    if cg2 != "OK" or vg2 != vg:
        print(f"FAIL: {PIN} broken — unrelated define perturbed the neighbor verdict")
        return 1
    print(f"PASS: {PIN} holds on the bench path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
