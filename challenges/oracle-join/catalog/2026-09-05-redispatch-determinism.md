# frontier-004 — re-dispatch determinism

Re-verifying the same work yields the same verdict: dispatching one
defined invention three times with the same argument returns
byte-identical OK lines. Borrowed from the FrontierHarness Eval v1
scoring rule (deterministic verifier pass/fail over all 30 tasks) @
`github.com/frontier-harness-eval/eval` @ `8f11b130` (2026-09-04).
No Exo pattern borrowed — snapshot/rewind, fork, and
experiment-history are taken by frontier-001/002/003; this card borrows
verifier flavor only. No task code, image, or verifier vendored; flavor
re-expressed on the bridge seam.

`bench/frontier/probe_frontier_004.py`: one Bridge defines greet
(`say`); three back-to-back `greet(msg: "hi")` dispatches must each be
`OK` with byte-identical detail. Beyond `frontier-001` (a rewrite
changes the body) and `frontier-003` (two names coexist): the SAME
name with the SAME argument never wavers.

Ran (worktree `.claude/worktrees/oracle-join-d`, zero model tokens,
canned lines only): `koruc mock-gate.k` → exit 0; `koruc
session-mock.k` → exit 0; `python3 bench/frontier/probe_frontier_004.py`
→ exit 0; neighbors `probe_define.py`, `probe_persist.py`,
`probe_440_012.py`, `frontier/probe_frontier_001.py`,
`frontier/probe_frontier_002.py`, `frontier/probe_frontier_003.py`,
`probe_vocab_live.py`, `probe_440_009.py` → exit 0 each. Full suite not
run (contest binding).

Would correct: `probe_frontier_004.py` fails, the case drops off the
wall, or the same invention with the same argument ever returns a
differing verdict.
