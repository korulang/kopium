# KOPIUM — handoff state (2026-10-13)

What this is: a tau2 airline arm where the model's only tool is a Koru
interpreter. The model emits wire (`verb(field: …)` invocations,
`note:`/`say:` channels, `| branch name |>` arms); `std/bridge` enforces
the declared scope's contracts; the bench marshal (`bench/tau_wire.kz`)
translates dispatched calls to tau2 tool calls. The system context is the
declaration's own render (`std/bridge:grammar`) — vocabulary, wire rules,
and the session's defined flows — spliced fresh ahead of the transcript on
every `ask`, so a `defined` flow joins the model's surface next turn.

## Verified working (with receipts)

- **The model speaks the protocol.** 122 replies across 6 task sessions
  (tasks 7/18/23, reasoning=none and medium): 58/67 multi-line programs
  at none; 21/25 `|>`-armed calls at medium task 18 (`call() | ok r |>
  note: r` — arm-then-inspect). rN field refs used (`r9.flights`,
  `r3.reservations`). Zero invented verbs, zero event-denied.
- **Vocabulary is in context.** `ask` renders `std/bridge:grammar(br)`
  per turn and prepends it as the system message — ~3.2KB, live, never
  fetched. Boot no longer stores a static block.
- **Growth works.** `bench/probe_sysblock.k` (offline, zero spend):
  `tor probe-verb { x: string }` + `probe-verb = …` through `bridge:run`
  → `defined`, and the re-rendered grammar lists `probe-verb(x: string)`.
- **Task 23 green** (was a persistent red): 1.0, db=True, 18 calls,
  $0.0039 vs stock $0.0229, 64s vs 98s.
- **Chained wire parses**: `call() | ok u |> call(u.field)` passes the
  gate (probe-verified through `bridge:run`).

## Open defects

1. **Marshal crash — bound refs in Source fields.** Receipt:
   `compare_livesys-medium.csv` task 18 err. The model wrote
   `flights: r9.flights` (legal wire — validation resolves rN at check
   time) but `Source`-typed fields reach the proc as raw text, and
   `callIO` (tau_wire.kz:342-356) splices `args_json` verbatim →
   unquoted `r9.flights` in the outbound JSON → `kopium agent emitted a
   non-JSON line`, task dead.
   **The design fork:** resolve `rN` paths inside `Source` fields at the
   marshal boundary, or have the validator refuse them with teaching.
   Currently it accepts then breaks. The seed in `tau-agent.k:348`
   teaches `flights: r9.flights` — the exact spelling that crashes.
   Fix the semantics, then fix or bless the seed.

2. **Empty reasoning burns.** With `KOPIUM_REASONING=medium`,
   deepseek-v4.1-flash repeatedly spends the full 16384-token
   completion budget on reasoning and emits zero wire: 14 of 30 turns
   on task 7 (~230k tokens, ~$0.25 of $0.34, produced nothing).
   Each empty reply gets a parse-error rejection and strikes against
   the fail bound. Levers: raise `max_tokens` (boot call in
   `tau-agent.k:385`), drop effort to `low`, or split reasoning from
   the wire channel. NOT decided.

3. **Stale reject strings — FIXED IN SOURCE, NOT REBUILT.**
   `koru_std/runtime.wirescan.kz:112` empty-reply and :223-224
   second-invocation messages taught "exactly one invocation per turn" —
   now teach "one or more invocations, one per line". `tau-agent-binary`
   was NOT rebuilt after this edit (don't rebuild mid-measurement;
   rebuild before next run: `koruc tau-agent.k && cp a.out
   tau-agent-binary`).

4. **Undersold surface (not model failures):**
   - Define syntax (`tor name { f }` + `name = body`) is absent from
     the grammar render → zero defines in 122 replies.
   - Call→call chaining never emitted (only call→note) — rN across
     turns is the cheaper path and nothing sells the same-turn payoff.
   - Fan-out (independent calls on consecutive lines, one turn) never
     used for parallel lookups — the rule states mechanics, not payoff.
   These are context/teaching gaps, not capability gaps.

## Measured boards

| run | tasks | koru | stock | notes |
|---|---|---|---|---|
| V4.1 board (`compare_v41board.csv`) | 29 | 23/29 | — | losses: 7,11,14,18,19,23 |
| V4.1 retry (`compare_v41retry.csv`) | 6 | 3/6 | reuse | 11,14,19 flipped; 7,18,23 red |
| livesys (none) | 7,18,23 | 0/3 | reuse | 0 wire rejections of note; judgment/starvation |
| livesys-medium | 7,18,23 | 1/3 | reuse | 23 green; 18 marshal crash; 7 db=True reward 0 |

Task 7: db=True + reward 0 = evaluator action/communicate check failed,
not the DB. `run_compare.py` now writes `eval.json` (full reward_info:
db_check/action_checks/communicate_checks) into each run dir — readable
from the next run onward.

## How to run

- Build: `cd bench && KORU_STDLIB=~/src/koru/koru_std ~/src/koru/zig-out/bin/koruc tau-agent.k && cp a.out tau-agent-binary`
- Probe (offline): same with `probe_sysblock.k`, then
  `KOPIUM_MODEL=test ./a.out` — renders system block, feeds a chained
  line through the gate, defines a flow and re-renders.
- Bench: `cd ~/src/tau2-bench && PYTHONPATH=~/src/kopium/bench
  KOPIUM_REASONING=none .venv/bin/python ~/src/kopium/bench/run_compare.py
  --ids 7,18,23 --suffix NAME --no-guard` — `.env` loads from the
  tau2-bench cwd (OPENROUTER_API_KEY); stock rows reuse
  `results/stock_baseline.csv` automatically.
- Receipts: `results/runs/compare-<suffix>-task<N>/receipts/` —
  `call_NNN.json` (exact request bodies), `resp_NNN.txt` (model wire),
  `session.json` (verdict counters), `eval.json` (new runs only).

## State

The wire layer holds: programs, arms, bindings, observer channel, live
vocabulary. The remaining reds are our defects (marshal leak, reasoning
budget), our teaching gaps (define/chain/fan-out undersold), and
evaluator-level check details — not DeepSeek misusing the language.
Every "the model doesn't do X" observed so far traces to something the
context never disclosed, never demonstrated, or never made pay.
