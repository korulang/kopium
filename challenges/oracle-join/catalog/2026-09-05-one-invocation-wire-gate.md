# frontier-005 — one-invocation wire gate

A wire turn carrying anything but exactly one complete invocation refuses
at parse time: prose, trailing text, a chained second call, and truncation
each REJECT with a model-directed diagnostic, and the session still
dispatches afterward. Borrowed from BFCL Simple (AST) — "one and only one
function call being invoked" @ `github.com/ShishirPatil/gorilla` @
`6ea57973` (main HEAD, 2026-03-23). No Exo pattern borrowed —
snapshot/rewind, fork, and experiment-history are taken by
frontier-001/002/003, verifier flavor by frontier-004; this card borrows
AST-scoring flavor only. No task code, data, or verifier vendored; flavor
re-expressed on the bridge seam.

`bench/frontier/probe_frontier_005.py`: one Bridge receives prose
(`hello there please say hi` → REJECT, "prose is not wire"), a clean call
with trailing garbage (→ REJECT, "nothing follows the closing ')'"), two
chained calls (→ REJECT, same rule), a truncated string (→ REJECT,
"looks truncated") — then `say(text: "hi")` still dispatches OK, proving
refusals never poison the session. Beyond `440_009` (an unknown VERB is
denied at dispatch): these turns never reach dispatch — the parse gate
refuses the SHAPE. BFCL scores at eval time what the bridge enforces at
parse time.

Ran (worktree `.claude/worktrees/oracle-join-e`, zero model tokens,
canned lines only): `koruc mock-gate.k` → exit 0; `koruc
session-mock.k` → exit 0; `python3
bench/frontier/probe_frontier_005.py` → exit 0; `python3
bench/harness-check.py` → exit 0, `12/12`. Neighbors touched: none —
no existing probe sends prose, trailing, chained, or truncated turns
(the gate's parse-error arm was previously unwitnessed on the wall).
Full suite not run beyond the wall (contest binding).

Would correct: `probe_frontier_005.py` fails, the case drops off the
wall, a non-wire turn dispatches OK, or a refusal poisons the session
so the closing legit call stops dispatching.
