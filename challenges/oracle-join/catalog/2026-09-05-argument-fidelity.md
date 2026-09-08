# frontier-006 — argument fidelity

A defined invention forwards the caller's argument values to its body:
the same invention dispatched with different arguments yields different
details tracking each call, and the same argument re-dispatches the
byte-identical detail. Borrowed from BFCL AST scoring — the emitted
call matches parameter VALUES, not just the function name @
`github.com/ShishirPatil/gorilla` @ `6ea57973` (main HEAD, 2026-03-23).
No Exo pattern borrowed — snapshot/rewind, fork, and experiment-history
are taken by frontier-001/002/003, verifier flavor by frontier-004;
this card borrows the VALUE half of the AST rule only (frontier-005
borrowed the COUNT half — "one and only one function call"). No task
code, data, or verifier vendored; flavor re-expressed on the bridge
seam.

`bench/frontier/probe_frontier_006.py`: one Bridge defines greet
(`say`); `greet(msg: "hi")` echoes `hi`, `greet(msg: "bye")` echoes
`bye` with no `hi` residue, `greet(msg: "hi")` again is byte-identical
to the first. Beyond `frontier-004` (the SAME argument never wavers):
DIFFERENT arguments never collide — the detail tracks the caller, not
the definition.

Ran (worktree `.claude/worktrees/oracle-join-f`, zero model tokens,
canned lines only): `koruc mock-gate.k` → exit 0; `python3
bench/frontier/probe_frontier_006.py` → exit 0; `python3
bench/harness-check.py` → exit 0, `13/13`. Neighbors touched:
`probe_define.py`, `probe_440_012.py`, `frontier/probe_frontier_001.py`,
`frontier/probe_frontier_004.py` (define/dispatch seam) → exit 0 each.
Full suite not run beyond the wall (contest binding).

Would correct: `probe_frontier_006.py` fails, the case drops off the
wall, a second argument echoes the first call's values, or the same
argument re-dispatches a differing detail.
