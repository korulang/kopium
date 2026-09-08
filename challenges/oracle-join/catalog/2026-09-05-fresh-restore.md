# frontier-002 — fresh restore

A fresh Bridge session starts identical and clean: an invention defined
in one live session is absent — from dispatch, vocabulary, and grammar
— in another, and two live sessions can hold divergent bodies under the
same name. Borrowed from the FrontierHarness Eval v1 harness protocol
(golden checkpoint → fresh restore per task, identical starting state,
no cross-task contamination) @
`github.com/frontier-harness-eval/eval` @ `8f11b130` (2026-09-04);
fork pattern (`snapshot → fork → diverge → assert`) from
`github.com/exoharness/exo` @ `7801005e` (2026-09-02). No task code,
image, or verifier vendored; flavor re-expressed on the bridge seam.

`bench/frontier/probe_frontier_002.py`: A defines greet v1 (`say`);
fresh B REJECTs `greet`, shows no `greet(` in `vocabulary()` or
`grammar()`; B defines greet v2 (`transfer-to-human-agents`, the fork)
and dispatches v2 while live A still dispatches v1. Beyond
`live-vocab` (one session's before/after): nothing crosses the session
seam in either direction.

Ran: `koruc mock-gate.k` → exit 0; `python3
bench/frontier/probe_frontier_002.py` → exit 0; neighbors
`probe_define.py`, `probe_persist.py`, `probe_440_009.py`,
`probe_vocab_live.py`, `frontier/probe_frontier_001.py` → exit 0 each.
Full suite not run (contest binding).

Would correct: `probe_frontier_002.py` fails, the case drops off the
wall, a fresh Bridge dispatches a foreign invention, or two live
sessions observe each other's bodies.
