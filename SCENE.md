# SCENE — kopium

*Read-many, write-rarely. Two clocks: this scene is slow and sticky; the repo
is fast and live. Scouts get the ideal user, NEVER this file. This scene
condenses from the membrane — it is a seed, planted 2026-09-04, and the
Gardener grows it as the corpus fills.*

## North star

Hand the runtime a `register` block and it *becomes* an interpreter for
that world — wire grammar, prompt, enforcement, and growth all derived
from the declaration. One declaration, four derived things; the same
binary runs a notes-agent, a git-agent, a math-agent.

## Ideal user

The agent-smith: a developer handing kopium a vocabulary on Friday and
expecting a working agent back — prompt, grammar, and enforcement derived,
refusals honest, resources held across turns. She judges a slice by
running it, never by reading about it. If it needs prose to explain
itself, it failed her. A new session can look at the resource world
and see what is still out — and why someone picked it up — before
it acts.

## Loose directions

- The REPL trellis: pin properties in the Koru `repl-properties` catalog
  (`challenges/021_repl_properties` on `wip-define-scope-filter`); bench
  only a number that would move if a catalogued property broke; grow
  that catalog, don't re-derive the pins in chat.
- R3: defined flows lower to native handlers at definition time (the
  summonable recompile, bounded by the vocabulary).
- The wired terminal agent, back against the derived prompt.
- A second domain vocabulary — parametricity is proven by two, not one.
- Model-sweep (wire family; catalog: transcripts).
- Harness-join (harness family): each replay adds a case to
  `python3 bench/harness-check.py` — the scoreboard for the decisions
  that make the τ³ path and the long-running bridge the same machine.
  τ³ compare is a different number (model spend).
- The wire as SSR (rugged aspiration, named 2026-09-12 — not the current
  focus): the model authors declarative source; the bridge renders every
  effect branch server-side; outcomes render back into context. The
  `bridge-mirror` map measures the distance — a `gap` row is a silent
  mis-render, a 200 that shipped wrong markup.
- The resource world is a place a successor can inspect: outstanding
  holds, how stale, the why of the last possess (`image.png` — the
  session that opened it wanted a resize). Vocabulary still persists;
  live fds still die with the process — the *record* is what a new
  session reads, then it re-acquires. History/provenance of a resource
  may be a sibling organ, not a column stuffed into the pool. Clients
  (parent, subagent, tomorrow's session) share that world; a run is
  exclusive on one bridge unless a pin says otherwise.

## What it says no to

- Trust-the-model tool surfaces (OS-permission kernels, JSON schemas
  checked by hand). Permission is a Koru declaration or it is a lie.
- Workarounds in the app for toolchain gaps. Green earned by dodging is
  shipped dishonesty; suspected gap → repro → hole → pin in koru.
- Prose as memory. Running code (gates, probes, pins) is the memory;
  documents are scaffolding — pruned the moment the code carries them.
- Persisting live fds across process death (ambient authority). The
  inspectable record is not the handle.

## Fog of war

- History as a sibling of the pool: named, not designed. What it
  stores, who writes it, whether the bridge only points at it.

## Tending log

- 2026-09-16: third vocabulary `headless/calc.kz` — no handles at all.
  `probe_calc.k` green across ten turns: payload bindings, refusal
  branches with no possession, the new bound-reference check, the
  vocabulary wall, derived field-membership, growth — all carried free.
  World state correctly crosses items while bindings die. The probe
  surfaced hole 9, the first seam in the DERIVED surface rather than
  the runtime: `WIRE_GRAMMAR_TEXT`'s chain example is hardcoded notes
  (`open`/`append`, "the handle the call just issued") — on calc it
  teaches verbs the wall will deny. SETTLED same day (koru
  `d7e6d3b0c`, ruled derive-the-cast): `scope-grammar` synthesizes the
  example from the scope's own manifest — `add | sum v |> say` on
  calc, `open | ok v |> append` on notes, no cast at all when nothing
  is provably chainable.
- 2026-09-16: last mirror gap closed koru-side (`15d8745ab`, pin
  `440_026`) — the catalogue is empty. An unbound identifier was
  stringifying to its own text: `append(handle: h)` dispatched
  `handle="h"` and failed `HandleNotHeld`, blaming the handle. Now a
  bare identifier is judged a reference at two walls: the wire parser
  refuses it at item heads (`step 2/2 parse-error — no bare values`),
  and arm bodies — Koru fragments where the shape parses — get
  `validation-error` naming the binding from a per-path bound set in a
  new `interpreter.args` part. `430_056`'s `pick(n: -1)` caught a real
  bug mid-fix (a leading `-` is a literal, not a ref). Three-boundary
  coincidence — parses = admitted = honoured — now holds on every
  measured cell; the "sensible subset" is executable, derived, and
  uniform across vocabularies.
- 2026-09-14: field-membership closed koru-side (`b4742ff96`) — and it
  is the first DERIVED enforcement: `validateFlow` judges provided fields
  against the scope's own `get_event_input` table, the same registry the
  prompt and dispatcher emit from. `InputLookupFn` now answers null for
  a name outside the scope (vocabulary membership stays `event-denied`).
  Pin `440_025`. The masquerade's subset boundary is now enforced by the
  register's own data rather than a hand-maintained list — the
  enforcement leg of derive-prompt-wire-enforcement-growth is real.
  Mirror gaps left: cross-item bindings (unbound identifier stringifies
  instead of refusing by name).
- 2026-09-14: mirror row 6 closed koru-side (`e132cf991`). `selectArm`
  now judges `when` guards in source order — the arm's binding
  provisionally in a scratch scope, first truthy wins, unguarded is the
  else, unjudgeable is a named `GuardUnjudgable` dispatch-error. New
  `interpreter.guards` part; pin `440_024`. The wire's "can never accept
  a chain eval would execute differently" invariant is true again. Open
  mirror cells left: cross-item bindings, unknown-field refusal.
- 2026-09-14: the `$mod`-in-plain-`fn` seam settled koru-side
  (`dca682df7`) — host lines at both emit sites run `rewriteModToBare`,
  so the spelling interpolates inside a module's own container exactly as
  proc bodies do. Koru `400_189` (parked aspirational since Aug,
  Lars-ruled) unparked and green; imported-module path verified by hand.
  All three seams the ledger spike surfaced are now closed.
- 2026-09-14: hole 8 settled koru-side (`0d3d699af`). Generated dispatcher
  bindings — locals, params, and module-level impl decls — now carry the
  `__koru_*` namespace user code cannot spell; event containers
  self-qualify `Input`/`Output` via `@This()`; and register-helper dedupe
  keys on the site's home module, fixing the merged-companion double
  transform that suppressed helpers. Pinned by koru `440_023`. The
  vocabulary author names their own state freely — the derivation no
  longer owns a hidden reserved-word list.
- 2026-09-14: hole 7 settled koru-side (`deb163cd8`). `CreateSpec.branch`
  names the outcome that carries a create; the acquire loop books the spec
  whose branch fired — `post` now nets zero, the probe exits clean, and the
  resource world stopped reporting holds for branches that never ran. The
  same normalized-name fix (`namesEql`, `-`≡`_`) unblocked kebab-named wire
  arms: `| bad-amount b |>` now matches the mangled `bad_amount` tag. Pinned
  koru-side by `440_022_branch_payload_acquires_once`.
- 2026-09-13: two fronts moved. `bridge-mirror` row 6: arm-level `when`
  (`| ok t when false |>`) parses full-fidelity, fires UNGATED on the
  bridge — selectArm never reads cont.condition; the wire's own "can never
  accept a chain eval would execute differently" header is now a measured
  lie. And the second vocabulary landed: `headless/ledger.kz` (accounts,
  balances, opaque acct handles) derived prompt, wall, hand-back, and
  growth from the register block alone — parametricity held — while
  surfacing two koru-side holes: branch-payload phantoms acquire one
  obligation per SPEC (not per fired branch; pool over-books, hang-up
  double-dispatches, module panics — hole 7) and generated dispatch locals
  shadow module state (hole 8). `probe_ledger.k` panicking at hang-up is
  the honest witness, not a bug to soothe.

- 2026-09-12: `bridge-mirror` planted — the interpreter↔compiler map.
  Seed + sweep, 5 rows: named arms/nesting/bindings transfer; `|?`
  parses-and-never-fires, `when` runs ungated with mangled args, the
  wire gate is single-item only, unknown fields never refused. The
  delta is a pattern: the interpreter parses more than it honors.
  Fix shape is one honesty wall, koru-side. Wire-as-SSR aspiration
  named (loose directions).
- 2026-09-12: wall repair + 13th `harness-join` replay. Probes rode the
  `ok string` contract (`| ok text |> say`), `consumers` compiles
  `headed.k` in tui/. New case `partial-denial`: a refusal mid-turn is a
  per-step report line, the turn runs on. `harness-check` 24/24.
- 2026-09-10: the wire flip landed — `wire:clean` keeps the whole turn,
  `extra-lines` is retired, and `std/bridge:run` (koru `e2c9bfc9a`) sequences
  multi-item turns with a per-step `?partial` report. New wall cases
  `multiline` + `consumers` (22/22); `headed.k` (broken since `5c683fc`) fixed.
  Live witness fired: turns 6 and 9 each composed two invocations in one reply
  (`steps: 2/2 ran`). Follow-on: `define-in-turn` proves a definition and its
  call run in ONE turn (`23/23`) — the growth payoff the old law blocked.
  `vulcan-forcing` + `live-define` un-paused. The fragment's multi- vs
  single-line experiment is the open move.
- 2026-09-08: the hand-back fires live — notes `read` gains `| ok | missing`;
  `notes-unhandled` joins the harness wall; live turn 5 witnessed
  `UNHANDLED branch=[missing]` and turn 6 the model explained it back.
  Consequence banked in frag-partial-programs: branch-returning verbs are
  two-turn under the one-invocation law (a bare `ok` hands back too) until
  continuation arms survive `clean`.
- 2026-09-05: resource world as successor-inspectable place (record,
  not live fd; history may be a sibling). Walk agreed; written here.
- 2026-09-05: first replay under the wall brief — 440_009
  (`catalog/2026-09-05-pin-440-009.md`) is a seventh case.
- 2026-09-05: harness wall planted (`bench/harness-check.py`).
  Six decisions, one exit code. Challenge brief now yields a case
  on that wall.
- 2026-09-05: sixth `harness-join` replay — live grammar
  (`catalog/2026-09-05-live-grammar.md`). `probe_440_017.py` green.
  Agent Koru lesson is `bridge:grammar`, not host prose.
- 2026-09-05: fifth `harness-join` replay — pin 440_012 on the
  bench path (`catalog/2026-09-05-pin-440-012.md`).
  `probe_440_012.py` green; redefine replaces the body.
- 2026-09-05: fourth `harness-join` replay — live vocab
  (`catalog/2026-09-05-live-vocab.md`). `probe_vocab_live.py` green.
  Agent prompt is `bridge:vocabulary` on the gate Bridge.
- 2026-09-05: third `harness-join` replay — mock on the session
  shape (`catalog/2026-09-05-mock-on-session.md`). `probe_session_mock.py`
  green. `vocabulary` lists register + `greet`.
- 2026-09-05: second `harness-join` replay — define on the gate
  (`catalog/2026-09-05-define-on-gate.md`). `probe_define.py` green.
  Same two-line source as `session.k` turn 4; table survives the line.
- 2026-09-05: first `harness-join` replay — persistent gate
  (`catalog/2026-09-05-persistent-gate.md`). `probe_persist.py` green.
- 2026-09-05: trellis named — REPL pins, benches that track them, Koru
  `repl-properties` generator. First new card: 440_018 (install-time
  scope filter), still on `wip-define-scope-filter`.
- 2026-09-04, plant (seed): condensed from KOPIUM_RUNTIME.md stance +
  install walk. Goal named: R3 flow-compiler.
