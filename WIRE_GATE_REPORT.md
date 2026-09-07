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

**Live ambiguity (probe `headless/probe_define_arms.k`, uncommitted):**
armed bodies install fine (`DEFINED choose`), dispatch dies with opaque
`ValidationFailed`. Unestablished whether that's the shape-checker
demanding totality or something dumber (arg validation, scope wiring).
Discriminating run: drop the `bad` arm and re-run — identical error means
not arm-counting; changed error locates the shape-checker.

## Repair shape (not started)

Sequencing goes in `run`: accept line-separated invocations, execute in
order, report per step. Demands a new branch shape for partial results
(step N ran, step N+1 refused) — the missing type from site 6. Then the
prompt sentences (including tonight's strip) flip to describe sequencing,
`clean` keeps whole replies, the probe contrast inverts, and the wall
guards the new shape. Two rulings owed by Lars before implementation:
stop vs continue at first failure; one observation per step vs a single
combined report.

## What would correct this report

A journaled ruling for the gate predating 08-17 (searched: none); or the
sequencing implementation landing with the wall green on the new shape —
at which point this file is history, not inventory.
