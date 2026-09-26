# Postmortem: the phantom-efficiency sweep

2026-09-26. What happened, why it was allowed to, and the rules that keep
it from recurring. Written because a ~15-hour benchmark ran on an
instrument that could not see the thing it measured — and produced a
headline number ("kopium is ~6-8x more token-efficient") that was false
from its first row.

## What happened

- `KopiumAgent` translates the model's wire reply into a fresh
  `AssistantMessage` for tau2. It never copied `usage`/`cost` off the
  litellm response. Every assistant message it emitted carried
  `usage=None`/`cost=None` — since the adapter existed.
- `f680044` added token/cost/wall metric columns to `run_compare.py`.
  tau2's `get_token_usage`/`get_cost` read those fields per message;
  messages without them are skipped (tokens) or zero the whole side
  (cost, via `agent_cost=None`). The columns therefore measured the
  **user simulator** — identical machinery in both arms — while the
  agent under test contributed zero counted tokens.
- `7837055` committed the phantom as a result: "smoke green — all at
  cheaper token+wall."
- `1a555ce` wrote the parity gate requiring a full refresh on current
  main. refresh1 ran ~9h overnight through an OpenRouter stall storm
  (two task-crashers, tasks taking 30-80min instead of ~5min);
  refresh1b restarted it with stall-degradation, then split into 4
  shards. Total wall ~15h before the shard run was aborted.
- 2026-09-26: traced the accounting, found every koru-side token/cost
  cell phantom (77 `has no usage` warnings in the run log, never read),
  killed the shards at koru 7/14 vs stock 12/14, committed the fix
  (`f0ba70b`) and the gate verdict (`51a6832`).

## Why it happened — five layers, each independently sufficient

1. **The translation boundary dropped accounting.** The agent rebuilds
   the provider's message — the spend lived on `response`, died at `out`.
   Nothing enforces that an emitted message carries its meter reading;
   tau2 warns per-message and continues. 77 warnings in the log; nobody
   reads warnings.

2. **A metric column was added without tracing one value.**
   `f680044` created the columns, the values populated, and the numbers
   looked plausible — because user-simulator tokens are real tokens.
   Sixty seconds tracing `get_token_usage` against one assistant message
   would have shown the field was absent.

3. **The error pointed in the project's favor.** "6x cheaper" flattered
   the thing being measured. Directional good news never got the
   suspicion budget that a 6x *worse* number would have drawn in the
   first minute.

4. **A binary question got a board-shaped answer.** The gate asked "did
   the wire flip move the score" — a sign test resolvable in ~6 tasks.
   The harness defaults to all tasks, so all tasks ran. The early-stop
   guard (`guard_check=10` per process) could never fire once the run
   was sharded into 6-7 task shards — the safety mechanism was
   structurally disarmed.

5. **Continuations inherited momentum, not doubt.** refresh1 → refresh1b
   → shards: each handoff carried "finish the board," not "should the
   board exist." Provider stalls made it look like weather worth waiting
   out rather than a signal to re-ask the question.

## The standing rules this sets

- **Trace one row before any sweep.** Before a compare/benchmark run is
  allowed to go long, a single row gets traced end-to-end: where does
  each reported column's number come from, and can it see the subject?
  A column that can't name its producer blocks the run.
- **Bounded probes answer gated questions.** A gate that asks "did X
  move" ships with a pre-registered N and a stop rule. Boards are for
  publishing, not for deciding.
- **Accounting is loud or the run is void.** If a harness emits
  "has no usage"-class warnings, the run fails fast — a metric that
  silently skips its subject is a silent fallback.
- **Shard-aware guards.** Early-stop thresholds are computed on the
  merged board across shards; a guard that can't fire is worse than
  none because it looks armed.
- **A handoff re-asks the question.** Any session resuming a long run
  states the question the run answers and the evidence already in hand
  before continuing it.

## What the record keeps

- `f0ba70b` — the fix: usage/cost summed across the turn's retries onto
  the returned message.
- `51a6832` — SCORECARD verdict: parity gate measured, failed. All
  pre-fix koru token/cost cells marked unmeasured.
- `concepts/frag-agent-usage-stamping.md` — the generalizable belief:
  a metric column is unmeasured until the producer stamps it.
- `concepts/frag-parity-gate-failed.md` — the ruling: shared-axis parity
  is not the rent; no more sweeps justified as "competes with stock."
- Shame wall: https://shamewall-lovat.vercel.app/c/x4z7xq9
