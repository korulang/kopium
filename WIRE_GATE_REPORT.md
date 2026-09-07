# Wire-gate damage report — the forcing ran backwards

Date: 2026-09-07. Status: inventory, not a fix. Tree carries uncommitted
prompt-strip edits (wire.kz rules/rules2, koru runtime.kz bullet); enforcement
untouched everywhere.

## Thesis

KOPIUM was supposed to be a forcing function for core functionality: the
agent's needs force Koru to grow (task → verb → pin-or-hole, the
vulcan-forcing loop). Instead the forcing ran backwards — Koru's core was
deformed to accommodate the harness: a single-invocation gate baked into the
toolchain's stdlib, prompt generator, parser, and dispatcher, with no ruling
behind it. The side project didn't force the core. It bent it.

## Timeline (from the record, not from memory)

- **2026-08-10** — Lars rules: swarm coding needs lenient compilation of
  *partial programs* — "compile and test programs that are just partially
  defined." (koru session, `prose grep -i "partial program"`; dissolved at
  the time as "lenient about absence, never about contradiction.")
- **2026-08-17** — the gate lands on koru main in two commits, one week
  later: `816f1c35` (parse.wire + bridge gates on it) and `2da2c392`
  (scope-grammar renders the rules, bridge:grammar adds inventions).
- **Between them: nothing.** 500 sessions searched; no decision for
  one-invocation exists. Not from Lars, not from anyone. It rode in as
  implementer's choice inside the wire-grammar branch and got written up
  afterward as "law" (R2).

The gate postdates the ruling it contradicts by seven days.

## Koru core sites (the deformation)

All in `koru_std/` — the toolchain every Koru program shares, not a
harness-local module:

1. `runtime.kz:2257` — `PARSE.WIRE` block header: *"the restricted wire
   grammar: one invocation, nothing else."* The general flow grammar
   (expressions, `|>` chains, multiple statements) is *"not expressible
   here"* — by decree, not by necessity. The interpreter's own parser
   builds the AST; the restriction is a pre-pass (`wireValidate`) that
   refuses shapes eval could execute.
2. `runtime.kz:2284` — `WIRE_GRAMMAR_TEXT`: the gate rendered as prompt
   bytes, shipped into every agent session. Law-language intact until
   tonight's uncommitted strip.
3. `runtime.kz:2385` — `parse.wire` tor: trim → `wireValidate` refuses →
   else delegate to the real parser. The real parser would take more; the
   gate stands in front of it.
4. `bridge.kz:182` — run discrimination + **206–219 THE WIRE GATE**:
   *"a turn on the bridge is ONE invocation and nothing else."* Every
   `std/bridge:run` call pays this toll, agent or otherwise.
5. `bridge.kz:334` — `grammar` render: rules + compiled base + inventions,
   *"the same declaration read twice"* — the boast that made the gate
   look designed. Lesson and law generated together means neither can be
   questioned separately; tonight questions both.
6. Branch sets (`run` 2495, `bridge:run` 165, `interpreter:run` 1337):
   single `result`, single `parse-error`. There is **no shape for "step 1
   ran, step 2 refused"** — partial results are unrepresentable, so partial
   programs are unthinkable. The type system enforces the gate most
   thoroughly where no prompt ever reaches.

Note what the core already contemplates: `fail_fast: bool` rides
`std/runtime:run` and the parser (continue-past-error machinery exists).
The orisha `POST /api/eval` endpoint runs chained multi-line Koru
(`add(a: 1, b: 2)` + `| sum s |> add(a: s, b: 100)`) against compiled
handlers — partial programs over the wire, working, demoed. The toolchain
can do it. The gate says it must not.

## Kopium pinning sites (our own wall guards the damage)

7. `headless/wire.kz` — `clean` keeps the head line; `extra-lines` counts
   the drop; `rules`/`rules2` taught obedience (stripped tonight,
   uncommitted).
8. `headless/live.k:199,234` — user-facing feedback strings: *"Reply with
   exactly one invocation and no prose"*, *"only the head ran."* Still
   live; they describe enforcement truthfully until sequencing lands.
9. `headless/probe_live_define.k:86` + `bench/probe_live_define.py` —
   the contrast case asserts two invocations keep only the head. **Our
   pit-of-success wall pins the damage green.** A green wall currently
   means the gate holds.
10. `headless/README.md`, `.claude/skills/kopium-toolchain/SKILL.md`,
    `KOPIUM_RUNTIME.md` R2 section — doctrine restating the gate as
    achievement. (README + SKILL stripped tonight, uncommitted; R2 text
    untouched.)
11. `challenges/live-define` transcripts — five replays of models obeying,
    evading, or colliding with the law. Evidence shelf for either outcome
    of the experiment.

## The distinction that organizes the repair (ruled in discussion 2026-09-07)

Shape-checking and running partial are different things, and the repair
needs both — composed, not confused:

- **Shape-checking is static.** All branches handled before anything runs
  (KORU022; strict-mode pre-flight per the 08-07 ruling). A property of
  the text. It answers: *may this run?*
- **Running partial is dynamic.** The uncovered branch that fires returns
  as an `unhandled-branch` outcome; the turn ends; the host handles it
  (lenient mode per the 08-07 ruling). A property of the run. It answers:
  *what happened, and what is owed?*

They compose exactly as 08-07 ruled: strict refuses pre-flight, lenient
runs and reports. Neither half alone is the product — strict-only is the
gate again, lenient-only is mush.

**Discriminated 2026-09-07 (probes `/tmp/probe_single.k`, `/tmp/probe_multi.k`, throwaway):**
single-arm bodies fail IDENTICALLY (`DEFINED`, then `REFUSED: ValidationFailed`) —
not arm-counting, not the shape-checker demanding totality. Two core defects instead,
both in the runtime-define path (`koru_std/interpreter.kz`), no harness involvement:
1. **Dispatch re-parse rejects what define accepts** — `define` validates with the full
  parser (inline arms `pick(text) | ok v |> ...` parse fine), but dispatch re-parses the
  stored `body_source` with lightweight `flow_parser.parseFlow` (`interpreter.kz:2536`),
  which expects arms on their own `|` lines and fails the inline shape. The `.err` maps to
  bare `error.ValidationFailed` (`interpreter.kz:2549`) with the parser's message
  ("Invalid invocation syntax") discarded — hence opaque.
2. **Define body extraction breaks on multi-line bodies** — extraction slices from
  `f.location.line` (`interpreter.kz:1299-1317`), but `Flow.location` is captured
  *after* continuations are consumed (`parser.zig:6305,6310` pattern:
  `.location = self.getCurrentLocation()` post-`parseContinuations`), so for any body
  with arms on following lines the slice starts past the `=`, finds no `=`, and refuses
  with "Definition body is empty". Multi-line armed bodies can never install.
Armed define has NEVER worked end-to-end (all witnessed live defines are
single-invocation). Per repo rule the fix lives in `~/src/koru`, not here: (a) capture
the impl head line for extraction, (b) teach `flow_parser` inline continuations (parser
parity), (c) surface the re-parse message instead of bare `ValidationFailed`.
**Landed 2026-09-07 (koru `wip-armed-define` c4bd1094, unpushed):** both
halves fixed — flow_parser takes inline arms (3 new unit tests, 24/24),
define locates the `<name> = ...` head by name (multi-line installs),
dispatch re-parse failure names flow + rejection + body. `define` moves to
`koru_std/interpreter.define.kz` (~part split, wall pin). Verified live:
single-arm, two-arm (both branches fire), multi-line — all dispatch.
Belief gardened as koru `frag-a-defined-body-must-parse-at-dispatch`.
Sequencing (multi-line RUN, partial-result branch) still open — the next
and larger half. Note: output builds link flow_parser from the installed
tree, so this lands for harness use on install, not on merge.

## Repair shape (armed-define c4bd1094 + sequencing 51139241 landed; experiment open)

Sequencing is BUILT (koru `wip-armed-define` 51139241, unpushed):
bridge:run segments items, routes each through the existing single
paths sharing pool + defined table, reports `?partial` (optional —
no caller changes; 440_008/012 match). Witnessed: PARTIAL 2/2,
mid-turn refusal continues, open→append→close chains note_0 in one
turn with the file holding the bytes. What remains: merge + install
(output builds link the installed tree), the fragment's experiment
(identical goals multi- vs single-line, cost-per-task votes), then
the kopium wall flips (live.k will owe a `partial` arm — KORU022
forces it loud at install).

## Sequencing stab (2026-09-07, probes throwaway in /tmp)

CORRECTION — the above stab worked from hearsay. The ruled text
(`concepts/frag-partial-programs.md`, banked 7250105, correction same
night) is explicit and this report now defers to it:

- Composition IS the product: "several invocations in one turn, chained
  through handles the interpreter just issued." Not handle-less notes —
  the experiment must chain FRESH HANDLES across steps in one turn.
- Guilty until measured innocent, with the experiment NAMED:
  multi-invocation turns vs the one-line law, cost-per-task and
  reliability vote. No rulings-by-taste owed on stop/continue or
  observations — the fragment prescribes measurement, and chaining
  implies continue-and-report (later steps consume earlier steps'
  outputs; stop-first would rig the experiment toward single-line).
- Rank is ruled too: composition is "load-bearing, not a luxury."
  Nothing here awaits a decision except execution and the experiment's
  outcome (which can correct the fragment itself).

Refusal, verbatim (`/tmp/probe_seq.k`): two invocations in one `bridge:run`
turn die as `parse-error: one invocation per turn: a second line is a
second turn`. Same for invocation-then-define. The refusal is honest and
precisely located (bridge.kz run discrimination + parse.wire gate).

Correction to this file's orisha note: the chained `/api/eval` demo
(`add(a: 1, b: 2)` + `| sum s |> add(a: s, b: 100)`) is ONE flow with arms,
not multi-invocation sequencing. `runtime:run` always accepted multi-line
single flows; the gate is bridge-level and item-shaped, not line-shaped.

(`DEFINED late` turn 2, `late(text:)` dispatches turn 3 — the session table
persists). That cross-turn path working does NOT demote one-turn
sequencing: the product is sending partial programs — one body, one
evaluation, every step run and reported. Cross-turn is the workaround;
one-turn is the purpose. Retract the latency framing above outright.

Sketch (no code until ruled): segment the turn into items with the full
parser (locations give `[head_i, head_{i+1})` slices — no new grammar, no
divergent splitter), move the `tor ` discrimination inside the loop so
mixed turns (invoke + define + invoke) route per item, thread session
state the loop already threads across turns (defined table, pool,
budget). Direction is derived, not open: CONTINUE past refusal and report
per step. Stop-first rebuilds the gate in miniature — one failure per
turn is N turns to discover N problems, the exact token burn the
partial-programs fragment exists to kill. `fail_fast` is parser plumbing,
not doctrine; doctrine is `frag-partial-programs`: run the body, report
every step, same as the orisha endpoint evaluates the whole chained body.
Per-step observations (the harness renders per-turn today; one entry per
step, no invented combined format).

Constraint, not a second design: do NOT invent a parallel partial-result
type beside koru-ub's in-flight `unhandled-branch` outcome. Sequence-level
partial is a different axis (WHICH step refused) than branch-level
(WHICH arm fired); a step ending in an unhandled arm under lenient mode
surfaces through their outcome shape, and the sequence wrapper reports
the step. Compose, don't fork.

Execution order (no further rulings owed): build sequencing in
`bridge:run` (segment items textually — a non-`|` line at depth zero
opens an item, `tor ` opens a define item; each slice still routes
through the EXISTING single paths so mis-segmentation fails loud
through today's validators, never silent), continue past refusal,
report one structured line per step under a new `partial` branch,
compose with koru-ub's outcome shape (no parallel partial type).
Then the fragment's experiment: identical goals, multi- vs single-line,
cost-per-task votes. Handle-chained (open→append→close), or it tests
nothing ruled.
A journaled ruling for the gate predating 08-17 (searched: none); or the
sequencing implementation landing with the wall green on the new shape —
at which point this file is history, not inventory.
