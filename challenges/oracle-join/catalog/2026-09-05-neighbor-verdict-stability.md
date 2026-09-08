# frontier-007 — neighbor-verdict stability

A defined invention's verdict is byte-identical before and after an
unrelated second define lands in the same session: the patch is
observable nowhere in the neighbor's OK-line bytes. Borrowed from the
DeepSWE post-patch regression rule — the FrontierHarness Eval v1 bar's
9 × DeepSWE (`datacurve-ai/deep-swe` v1.1) tasks re-run the repo's
existing tests after the patch @
`github.com/frontier-harness-eval/eval` @ `8f11b130` (2026-09-04).
No Exo pattern borrowed — snapshot/rewind, fork, and
experiment-history are taken by frontier-001/002/003, verifier flavor
by frontier-004, the COUNT half of the BFCL AST rule by frontier-005,
the VALUE half by frontier-006; this card borrows DeepSWE regression
flavor only. No task code, image, or verifier vendored; flavor
re-expressed on the bridge seam.

`bench/frontier/probe_frontier_007.py`: one Bridge defines greet
(`say`) and snapshots its OK line, defines farewell
(`transfer-to-human-agents`, the unrelated patch) and asserts farewell
dispatches its own body (the patch genuinely landed, else the case is
vacuous), then greet re-dispatches byte-identical to the snapshot.
Beyond `frontier-003` (both names stay dispatchable — a coarse
body-check that passes even if the detail drifts): the neighbor's
VERDICT never wavers. Beyond `frontier-004` (the SAME name re-run):
an UNRELATED name lands in between.

Ran (worktree `.claude/worktrees/oracle-join-g`, zero model tokens,
canned lines only): `koruc mock-gate.k` → exit 0; `koruc
session-mock.k` → exit 0; `python3
bench/frontier/probe_frontier_007.py` → exit 0; neighbors
`probe_define.py`, `probe_440_012.py`,
`frontier/probe_frontier_001.py`, `frontier/probe_frontier_003.py`,
`frontier/probe_frontier_004.py`, `frontier/probe_frontier_006.py`
(define/dispatch seam) → exit 0 each; `python3
bench/harness-check.py` → exit 0, `14/14`. Full suite not run beyond
the wall (contest binding).

Would correct: `probe_frontier_007.py` fails, the case drops off the
wall, or a neighbor's OK line differs by even one byte after an
unrelated define.
