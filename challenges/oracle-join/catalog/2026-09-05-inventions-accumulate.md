# frontier-003 — inventions accumulate

Two distinct inventions accumulate in one session: defining a second
flow never evicts the first — both stay dispatchable and both render
in vocabulary and grammar. Borrowed from the FrontierHarness Eval v1
harness protocol (all 360 evaluations — 30 tasks × 12 configs —
retained in `results/eval-data.json`, every trial kept) @
`github.com/frontier-harness-eval/eval` @ `8f11b130` (2026-09-04);
experiment-history pattern from `github.com/exoharness/exo` @
`7801005e` (2026-09-02). No task code, image, or verifier vendored;
flavor re-expressed on the bridge seam.

`bench/frontier/probe_frontier_003.py`: one Bridge defines greet
(`say`) and dispatches it, defines farewell
(`transfer-to-human-agents`, the second experiment) and dispatches
it, then greet dispatches its own body again; `vocabulary()` and
`grammar()` render both names. Beyond `frontier-001` (one name
rewritten and rewound) and `frontier-002` (nothing crosses the
session seam): two distinct names coexist in one session's table.

Ran: `python3 bench/frontier/probe_frontier_003.py` → exit 0;
`python3 bench/harness-check.py` → exit 0, `10/10`.
Full suite not run (contest binding).

Would correct: `probe_frontier_003.py` fails, the case drops off the
wall, a second define evicts the first, or vocabulary/grammar loses
an invention.
