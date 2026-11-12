# STATUS-R4 — doctrine layer v1: guides that fire at chain position

**Verdict: Phase A landed and deterministically verified.** 31 compiled guide
rows, dispatch-time lookup in `std/bridge`, `fired_guides` stamped from the
same lookup, and a no-LLM replay harness at **93/93 passing, 0 failed, 2 dark
rows**. Phase B not built; a concrete spec is below. Committed in both repos.

| | |
|---|---|
| koru | `koru_std/guide.kz` pub match API, new `koru_std/bridge.guide.kz`, `fired_guides` + guide text in the run report |
| kopium | `bench/airline_guides.k` (31 rows), `bench/build-airline-gate.sh`, `bench/guides-replay.py`, gate/agent wiring |
| spend | **$0.00** — no hosted API, no ollama; every check deterministic |
| split | `SPLIT GATE PASS — no test-20 ids in selection (30 ids)`; content carries no task ids/trials/seeds |
| corpus | `combined-r2r3-callstep.jsonl` only (2,790 records / 2,335 dispatches, train-30) |

---

## What was built

### 1. Guide content — `bench/airline_guides.k` (31 rows, 3 classes)

Compiled through `std/guide:add` into `guide_table.txt` beside the binaries
(sha256 `dee091a8…`). Every row is domain-general; slots only, no task data.

| class | count | keys | source |
|---|---|---|---|
| field-name truth | 14 | bare `tor` (every tool) | `airline_tools.k` signatures + payload key sets mined from the corpus |
| workflow exemplars | 10 | `tor->ok` | canonical verb sequences counted from the corpus |
| judgment frames | 6 | refusal/surprise edges | `policy.md` clauses |
| generic edge | 1 | `*->error` | "read the payload, don't repeat the identical call" |

Field truth is the class the local probe motivated: the real payload names
(`payment_methods` is an **object keyed by payment id**; a reservation has
`payment_history[].amount`, not `payment_methods`; `name.first_name`,
`saved_passengers`, `available_seats.<cabin>`, `prices.<cabin>`, …). Workflow
rows are the mined chains, rendered as next-step templates with slots:
`get-user-details → get-reservation-details → (search-* →) update-*|book|cancel`.
Judgment rows adjudicate the observed failure edges: `book-reservation->error`
("amount does not add up" vs "not enough balance"), `update-reservation-flights->error`
(one payment method, basic economy cannot change flights), `get-user-details->error`,
plus policy frames on cancellation conditions, flight status bookability,
transfer scope, and compensation amounts.

### 2. Dispatch-time lookup — `koru_std/bridge.guide.kz`

- **Where**: `emitCallSteps`, the one boundary that already holds each
  dispatch's `TraceEntry` (verb, branch, failed). The lookup fires from the
  record's own facts; there is no second source of truth.
- **Key**: `tor->branch` edge row first (a failed dispatch is its tor's `error`
  edge; the generated airline tors declare `| ok | error`, so an ordinary
  success is `ok`), then the bare `tor` row (field truth). Up to two rows per
  dispatch, edge first.
- **Once per TABLE key per session**, in a bridge-held fired-set ledger (the
  membrane's per-session graduation). A wildcard row attributes to itself.
- **Specificity is `std/guide`'s**: exact key first, then best wildcard
  specificity (2 concrete sides > 1 wildcard side > none). The rule is
  re-implemented in the bridge because a side-effect-only `std/guide` import
  runs the add transform but is **not emitted** into the program (measured) —
  nothing callable survives to read the table. The bridge is the runtime
  consumer, so it owns the read; `guide.kz` remains the semantic owner and the
  two `matchKey` bodies are marked as a pair.

### 3. `fired_guides` recording

`emitCallSteps` writes `fired_guides:[<table key>, …]` per call_step record
(from the same lookup that renders the text), so corpus rows can attribute
guide effects. Wildcard firings record the wildcard row's key, never the query.
Item-coverage records (define/refusal/residue) keep `[]`.

### 4. Injection seam — chosen, and why

**The item's own report, gate-authored.** Guide lines are appended where the
run already reports that item:

| outcome | text slot |
|---|---|
| single-item `result` | `result.trace` (rendered before `result:`) |
| single-item `dispatch-error` | `RunError.trace` |
| single-item `unhandled-branch` | new `guides` field on `std/bridge:run`'s arm (gate HALT line + `tau-agent` observation) |
| multi-item turn | `runSteps` report, one `guide <key>: <template>` line after each step result |

Why here and not a separate event or Python prompt assembly:

- **One lookup, two consumers.** The line and the record come from the same
  `fireGuideForEntry` call, satisfying the proposal's "the log and what the
  model saw cannot disagree."
- **Koru stays authoritative.** The guide is heuristic periphery, but a
  refusal edge is reported by the gate that refused; the guide rides that
  report rather than a parallel channel a harness could forget to drain.
- **The live model path is the same path.** `tau-agent.k`'s `act` already
  prints `r.trace` / the step report / `ub.guides` verbatim into the observed
  message, so no new prompt-assembly surface was created.
- **The gate's stdout carries it too** (`OK` trace continuation, `STEPS`
  report, `HALT` detail), which is what the replay harness asserts on.

### 5. Deterministic verification — `bench/guides-replay.py`

Reconstructs recorded corpus wires from `call_step.args[].raw` (skipping
reference args and failed dispatches), runs each through a fresh
`airline-gate-binary`, and asserts (a) the expected TABLE key is in
`fired_guides`, (b) `guide <key>: <template>` appears in the turn's
model-visible stdout, byte-equal to the compiled table row, (c)
`fired_guides` is populated — plus once-per-session silence, exact-row beats
`*->error`, and a `say` control that must inject nothing.

```
$ python3 bench/guides-replay.py
table: .../bench/guide_table.txt (31 rows)
corpus: .../bench/corpus/combined-r2r3-callstep.jsonl (2790 records)

DARK send-certificate->ok — never observed in train-30 corpus (row authored, unexercised)
DARK send-certificate — never dispatched in train-30 corpus (row authored, unexercised)

93 passed, 0 failed, 2 dark rows
```

Gate protocol regression unchanged: `python3 bench/gate_probe.py` →
`24/24 passed` on the rebuilt binary. Koru pins: `480_001_guide_add_transform`
PASS; the `440_RESOURCE_BRIDGE` battery — **54/54** (the 440_001–440_056 set)
— PASS on the final tree.

The battery exposed a pre-existing latent defect in `std/bridge`
(4 tests regressed since 2026-11-11): `bridge.itemrec.kz`'s
`refusedSingleItem` named the bridge's own `run_event.Output` in a
module-level signature, so any program that compiled `std/bridge` without
invoking `bridge:run` (e.g. 440_004's create/close-only program) failed with
`use of undeclared identifier 'run_event'`. Fixed minimally: the signature
takes `comptime Out: type`; the caller (inside the `run` proc, where the
symbol exists) passes it. Verified by re-running those 4 tests, then the whole
battery.

---

## Phase B — spec (not built)

**Live-binding exemplar instantiation.** The gate knows the session's durable
bindings and their field sets (`Environment.fields`; `vocabulary()` already
renders `r3 {reservation_id, user_id, …}`). Phase B renders the *slot* side of
an exemplar row from that live state instead of leaving `"<id from the user
reservations>"` as prose.

Concrete shape, schema-shaped not value-parroting:

1. Extend the guide table's row contract with an optional binding hint, e.g.
   `std/guide:add(update-reservation-flights -> ok) { … }` unchanged, plus a
   machine part in the template: a `$bind:<arg-name>` token naming the input
   field an argument wants.
2. At render time the bridge resolves each token against the session env:
   find bindings whose field set contains that input name and emit
   `reservation_id: r1.reservation_id` (name + field path only — never the
   value), capped at one line per token. No match → render nothing.
3. Keep the static text as fallback; tokens are additive. The `fired_guides`
   record already names the row, so a rendered-vs-static variant is
   attributable without a schema change.

Why this is safe: it reads only binding *names* and *field names* the session
already discloses in `vocabulary()`, and the wire evaluator still judges every
spliced value. Why it is not free: choosing a binding is a heuristic that can
be wrong (two reservations held), which is exactly the "trusted core, heuristic
periphery" contract — the gate still refuses an illegal splice.

Koru-side file shape: the line-growth wall pins every `koru_std` file, so
the new code was split into flat parts — `calls` keeps the record tails while
the serializer moved to `bridge.recording.kz`; `error` keeps the error union
while the outcome mapping moved to `bridge.outcome.kz`; `itemrec` keeps the
define/residue handlers while `refusedSingleItem` moved to
`bridge.singleitem.kz`; `guide` keeps the transform and tors while the match
API moved to `guide.match.kz`. `core` and `runsteps` were trimmed back under
their pins rather than split, because a comment-only part file trips
`kz-extension-is-earned` (a `.kz` with zero host content is convertible).
Baselines regenerated: shrink rows + new files only.

---

## Honest limits

- **Semantic effect on a live model is NOT measured.** The rails are proven
  deterministic: content compiles, fires at the right dispatch, reaches the
  model channel, and is recorded. Whether the model *reads better* is a spend
  experiment (ollama, after this gate), untouched here.
- **`send-certificate` rows are dark** in the train-30 corpus (0 dispatches;
  R3 documented the same at the edge level). Authored from schema + policy,
  exercised only synthetically.
- **Once-per-session** means a long run sees each row once; a 30-turn session
  firing 8–12 rows adds maybe 2–4 KB. That is deliberate (anti-flood,
  per-session graduation), but the cap is empirical, not measured.
- **Templates are single-line by the substrate's design**: the `add` transform
  collapses newlines and the flow parser owns `|>` and `'` inside a source
  block, so templates cannot carry wire chains, apostrophes, or multi-line
  formatting. Content is written around that; a richer template language
  (e.g. `@"file"` embeds, per the proposal) is not wired.
- **Table hash is not yet stamped into run provenance.** The table ships as
  `guide_table.txt` (ignored build artifact) regenerated by
  `bench/build-airline-gate.sh`; a `run_start` guide-table hash is a one-line
  follow-up for attribution across regenerations.
- **The gate binary is rebuilt locally, uncommitted** (`bench/*-binary` is
  gitignored). Rebuild with `./build-airline-gate.sh`; it removes the stale
  table first because `add` appends.
- `tau-agent-binary` was rebuilt in place to carry the rails; it reads the
  same directory's `guide_table.txt`.
