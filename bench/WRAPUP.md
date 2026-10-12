# tau2 benchmark arc — wrap-up

Closed 2026-10-12. The question was whether KOPIUM's declared-wire agent
surface loses to stock tau2 JSON tools on the same model
(`openrouter/deepseek/deepseek-v4-flash-0731`, 29 airline tasks).
The work is abandoned. This file is the account of what was actually
measured, what was broken along the way, and what was never measured.

## The headline number

**Best honest board: koru 23/29, stock 27/29** — single trial, both arms
as shipped (`compare_think_on_*` shards, reconstructed per-task with
re-flight overrides; see "board record"). Koru losses: 7, 9, 10, 14, 23,
24. Stock losses: 7, 22. The residual 4-task margin is inside
single-trial noise — never resolved before the arc closed.

A clean wire-vs-stock board on the final prompt artifact was never
flown. The most legible statement the record supports: with equal
reasoning and a sane prompt, koru is somewhere in stock's neighborhood,
not clearly behind and not proven at parity.

## Board record — what each artifact measured

| artifact | koru | stock | verdict |
|---|---|---|---|
| early boards (pre-think_on) | ~17–23/29 | ~25–28/29 | confounded — koru sent `reasoning: effort "none"` while stock thought by default |
| `parity_off` (stock's thinking forced off via Python) | 20/29 | 24/29 | **disqualified** — measured a race nobody runs; shamewall jc6nb7q |
| `think_on` (koru medium, stock untouched) | **23/29** | **27/29** | the honest board. Tasks 1, 20, 21 flipped to wins at task level; 14 stayed a certificate-policy loss |
| `kernel3` smoke (pull-everything: vocabulary()/contract() verbs, ~550-char kernel) | 2/3 | 2/3 | pull worked but the model burned turns asking for its own verbs; rejected as a design error |
| `smoke-min` (160-char kernel, pulls only) | 1/3 | 3/3 | same bootstrap tax |
| `vocabshot` (kernel + vocabulary render + 3 real example turns in system prompt) | 2/3 | 2/3 | smoke only; no bootstrap pull needed; board never flown |

## Confirmed defects found — the actual product of the arc

All fixed in the wire/harness, Koru-side, unless noted:

1. **Reasoning-off default.** `tau_wire.kz` sent `effort: "none"` while
   stock thought. The single largest confound. Fixed `69e57e0`
   (default `medium`).
2. **Unbounded generation.** `max_tokens` at 100000 let a thinking
   turn burn the entire completion budget and emit an empty wire turn —
   four tasks died on 900s watchdogs. Fixed `69e57e0` (16384 bound).
   Residual failure mode still live: a full-budget reasoning burn can
   still emit an *empty* turn that silently eats a tool call (task 21,
   kernel3 receipts) — the harness does not tell the model nothing
   dispatched. Never fixed.
3. **The front-load.** Koru's system message was 16.5k — a wire-grammar
   manual and tool contract occupying the first 8,856 chars, with the
   airline policy behind it. Stock's system message *is* the ~8k policy.
   Every pre-fix board measured "model reads a manual first," not the
   wire. Fixed in the vocabshot worktree (uncommitted): system is now
   ~2.9k of kernel + vocabulary render + three real example turns, then
   policy — 10.6k total vs stock ~8k.
4. **`name<!x>` in model-facing grammar.** The consumption-annotation
   spelling was being taught as writable wire. Removed at the koru repo
   (`cea2700c0`); the annotation lives at declaration level only.
5. **`note:` went dark when reasoning turned on.** The observer channel
   was the hearing instrument — 9–22 notes/task on the no-reasoning
   board, ~0 on the think-on board: cognition routed around the
   instrument. The streamed `reasoning` field is never captured into
   receipts and never replayed into history — invisible to us and to
   the model's own later turns. Never fixed.

## Design rulings made along the way

- **Pull-verbs for depth, not for existence.** Making the model call
  `vocabulary()` to learn its verbs was tried (kernel3) and ruled out:
  the agent must not spend turns asking what its hands are. The
  vocabulary render belongs in the prompt (byte-identical to what
  `vocabulary()` returns — no drift); `contract()`/`grammar()` stay
  pull-verbs for field-level detail.
- **Examples teach, rules don't.** Three verbatim trimmed turns from
  real receipts (call→result→say, contract-pull→complex call,
  note-plus-call) went into the prompt instead of more instruction
  prose. Smoke showed first-try correct spellings without a bootstrap
  pull.
- **Over-prompting is sediment.** Every observed failure produced a new
  instruction line until the kernel was itself a manual. The fix that
  survived is two lines plus demonstration.

## Never measured

- The vocabshot artifact on all 29 tasks — the one board that would
  have answered the original question.
- Whether `note:` stays useful with reasoning on (needs reasoning
  captured into receipts to even observe).
- The empty-turn defect under medium reasoning — observed once, not
  bounded.
- Whether 23/29 vs 27/29 holds on a second trial.

## State on disk

- `bench/tau_wire.kz`, `bench/tau-agent.k`, `bench/gen_airline.kz`,
  `bench/airline_tools.kz` (+ the run_*.py/measure.py touch-ups) are
  **modified, uncommitted** — the vocabshot artifact lives only in the
  worktree. `git diff bench/` reproduces it.
- Committed fixes: `69e57e0` (reasoning + token bound), `acae2bf`
  (scorecard account), koru-repo `cea2700c0` (`<!x>` spelling).
- Receipts for every run: `bench/results/runs/compare-*/receipts/`.
  The board CSVs: `bench/results/compare_*.csv`.
- `run_compare.py`'s `reasoning` CSV column reads an env var, not the
  wire — it printed "none" while the request sent "medium". Label bug,
  noted so nobody reads it as ground truth again.

## Cost

Session ledger roughly $9.27 → ~$8.15 across the arc's final leg
(the rigged board ~$0.26 of it — spent against the goal, on the wall).
Every board was cents; the waste was never the money, it was flying
confounded artifacts and scoring them as verdicts.

## Conduct record

The parity-off board — fixing the comparison by hobbling stock instead
of fixing koru — is posted: <https://shamewall-lovat.vercel.app/c/jc6nb7q>.
Several mid-session claims were asserted before being read from receipts
and got corrected in-flight; the ones that survived are the ones in this
file, each tied to a CSV or receipt path above.
