---
challenge: bridge-mirror
kind: generator
status: standing
yields: one row of the interpreter↔compiler map — one construct, both surfaces, a verdict
catalog: ./catalog
family: harness
created: 2026-09-12
---

*Walker context: the bridge interpreter is a second Koru. `interpreter:parse`
runs the same `flow_parser` the compiler does, then evals against registered
dispatchers; `runtime:parse.wire` narrows that further for the model
(`verb(field: "value")`, string fields, `| arm |>` chains). Nobody has ever
written down where the three surfaces diverge — which flow constructs the
interpreter runs, which it refuses honestly, and which it silently
mis-handles. Every "can the model do X" talk that does not add a row
re-derives the question. The catalog IS the map: this generator grows it.*

*Siblings stay independent. `harness-join` grows joins on the wall;
`oracle-join` borrows outside oracles. This brief measures a delta between
two surfaces that already exist — its output is a matrix, and rows that
expose a real lie may hand a pin to koru or a case to the wall, but the
row itself is the yield.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Do not ask which construct to map. Read `./catalog/`
first — every mapped construct is a row with a verdict. Pick one flow
construct **not already a row** and measure it on the surfaces below.
Variance is the metric: a replay that re-measures a mapped construct is a
re-run, not a replay.

The three surfaces, in order of narrowing:

1. **Compiled Koru** — `koruc` on a `.k`/`.kz`. The full language.
2. **The bridge interpreter** — a source string through `std/bridge:run`
   (or `std/runtime:run` where the bridge adds nothing). `interpreter:parse`
   accepts it, eval runs it — or it refuses with a named outcome.
3. **The wire** — `app/wire:clean` + the single-item gate. The agent-facing
   subset. Some constructs are narrowed here *on purpose*; the row records
   intent, not just behavior.

A row is: **construct → compiled verdict → interpreted verdict → wire
verdict → class**. Class is one of:

- `supported` — same semantics on both surfaces.
- `refused-honest` — a named refusal (parse-error, event-denied, shape-error)
  that says why. A deliberate narrowing counts: record the intent.
- `gap` — silent divergence, a wrong verdict, a panic, or a refusal that
  lies about the construct. A gap is a *found* seam, not a failed replay —
  the card names the disposition it wants (koru pin, deliberate narrowing,
  fix) and small ones may land it.

1. Name the construct in one sentence that can be wrong.
2. Measure it: the smallest compiled program that exercises it, the
   smallest bridge `source:` that exercises it. Canned only — no model
   spend; a construct that needs a model to test is the wrong construct.
3. Append `catalog/<yyyy-mm-dd>-<construct>.md`: the row, the probe
   paths, exact outputs or exit codes, the class, and — for `gap` — the
   observation a successor would run to confirm it is still open. Where
   the verdict is `supported` on the agent path and the property is a
   decision worth keeping, a `bench/` probe + wall case carries it; a
   `refused-honest` or `gap` row is a card, not a case.

Done-gates (mechanical): the row is measured in this session, not
extrapolated — every verdict cites a run you ran; the catalog file exists;
any probe it lands is wired where it claims to be; no model spend. A
`gap` row with no runnable repro is a rumor — the repro is the row.
Taste-gate: the human can read the catalog top-to-bottom and see the map
getting wider, one construct at a time.
