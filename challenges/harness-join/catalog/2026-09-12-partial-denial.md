# 2026-09-12-partial-denial — a refusal mid-turn is a step line, the turn runs on

Join (one sentence that can be wrong): a denial inside a multi-item turn is a
per-step `event-denied` line in the `?partial` report — never the turn's
verdict — and the items after it still run.

The wire flip (`2f500f3`, koru `e2c9bfc9a`) made sequencing claim "a partial
program RUNS, continuing past refusal" (`koru_std/bridge.run.kz`). The wall
witnessed the green half — `multiline` pins `partial 2/2` on two good steps —
and nothing pinned the refusal half: a turn whose middle is `delete` (never
declared on `notes`) between two runnable verbs. The path that was still a
fork: the τ³ agent's per-step report could quietly become a turn-level
`event-denied` — the model loses the outcomes of every step after the first
refusal — and no case would go red.

Landed: `headless/probe_partial_denial.k` drives `delete → say → delete`
through `app/wire:clean` + `std/bridge:run`, canned. Observed: `partial 3/3`,
`step 1/3 event-denied: delete`, `step 2/3 result`, `step 3/3 event-denied:
delete`, the `say` fired, and a follow-up single-item turn runs clean.
`bench/probe_partial_denial.py` is wall case `partial-denial`.

Ran: `python3 bench/probe_partial_denial.py` → exit 0;
`python3 bench/harness-check.py` → 24/24.

Would correct this card: `partial-denial` goes red — a denied step aborts the
turn, the report stops naming per-step verdicts, or the bridge dies with the
denial. Also if `?partial`'s contract changes shape (e.g. `ran` starts
counting successes rather than items — today `ran == total` always, the
report string is where truth lives).
