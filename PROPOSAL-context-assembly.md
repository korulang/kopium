# PROPOSAL — context assembly: the system prompt is a guide

Status: design converged 2026-11-09, unimplemented. Captures rulings
migrated out of n-grams/rd.md — the research log stays the lab notebook;
this repo owns the build.

## The rulings

### 1. The system prompt is guide data, not a superstring

Today `AirlineLldaAgent.get_init_state` concatenates `gate.grammar()`
+ tau2 `domain_policy` into one ~19.4k-char blob. That blob is three
provenance classes wearing one coat:

- **Derived** — wire grammar prose, vocabulary, tool contract. Emitted
  by the register/vocabulary derivation inside the gate binary.
- **External** — tau2's domain policy (~7.8k). tau2-bench owns the text;
  for the smart-tool future it is just more teaching data the tool
  declares, not a special injected channel.
- **Tuned** — examples and framing prose. Hand-maintained today; the
  prime overprompting suspect.

Ruling: the prompt becomes guide entries keyed by section (`system`,
`system:vocabulary`-style keys TBD), rendered by the context assembler.
Guide storage stays dumb — derivation emits the entries (inline
blocks, `@"file"` embeds, or transform-generated table rows); nothing
is hand-duplicated. `@"path"` is the verified file-source spelling
(koru pins 620_008/620_009) — `guide:add(system) @"system.md"` compiles
the same bytes as the inline block.

### 2. Anti-overprompting is architectural, not editorial

Always-on context = a declared, small set of keys. Depth moves to
on-demand lookup: edge guides fire on surprise, priors render per
state. You cannot ship 19k chars of always-on context by accident if
the always-on tier is a key list. The portal shows provenance per
block (inline / file@commit / generated).

### 3. Surprise-gated guides

Guide value is conditional on surprise. Two cheap prediction sources:
the armed branch is the model's prediction (`| ok r |>` predicts ok;
unarmed outcomes already surface as unhandled-branch), and the n-gram
prior gives an empirical branch distribution per tor/state — actual
vs modal = computable surprise score. Surprise is self-limiting
(priors sharpen → guides fade = built-in graduation) and a dial, not
a switch: mild → hint, wild → full lesson + trajectory replay.

### 4. Trusted core, heuristic periphery (the Turchin rhyme)

Gate/interpreter = verified core; guides/priors/context = heuristic
periphery allowed to be wrong. Same architecture as supercompilation's
driver+strategy split, inverted correctness regime: his periphery must
be sound, ours is allowed to err because the gate rejects illegal acts
and the evaluator scores outcomes.

## What exists vs what is missing

Exists: runlog.py JSONL schema (gen events carry full assembled
context), portal/ SvelteKit viewer live on :5199, guide attach/lookup
proven in koru (480_001 green), n-gram prior pickles, gate vocabulary/
grammar derivation.

Missing, in dependency order:
1. ~~**Say-protocol desync**~~ — RESOLVED 2026-11-10. See findings
   below; gate_probe is 18/18 on the rebuilt binary and task 14 is
   re-running clean.
2. ~~**`state()` contract**~~ — IMPLEMENTED 2026-11-10 (koru_std:
   `state()` host verb in bridge.wiregate/hostverbs, render in
   bridge.state.kz, HostView extended with turn_env/run_env/
   handle_pool/trace). Renders `durable:` (session_env values as
   JSON — vocabulary shows names+fields only), `turn:` (arm names,
   multi-item turns only), `item:` (run-env names neither layer
   claims — chain-internal arms on single-item turns), `held:`,
   `defined:`, `path:` (this item's dispatches so far). Measured
   surprise pinned in frag-bindings-scope-in-three-layers: single-
   item turns pass turn_env=null, so `call | ok u |>` on one line
   binds u into the run env only. gate_probe 23/23 (5 new state
   cases); koru pins 440_031/033/043 updated + green.
3. Context assembler — reads state + guide table + priors + surprise
   score → renders the per-turn payload; replaces the static
   system+transcript concat.
4. Guide delivery — file spike (guide_table.txt) → AST `appended`
   injection (koru-side, queued).
5. Liquid `{{ }}` collision — wire teaches literal `{{ u.field }}`
   splices; guide templates through Liquid will eat them. Escape story
   or different sigil needed before teaching text rides templates.
6. Module-resident `guide:add` — grammar ambiguity TODO-pinned in
   koru (115_063); impl-flow source-block binding unresolved.
7. **`scopeChainExample` picks nonsense chains** (koru-side, found in
   the prompt audit): `runtime.example.kz` mechanically selects head =
   first payload-branch/`__type_ref` verb and target = fewest-arg
   "sink". On airline it renders `say(text:"1") | ok v |>
   calculate(expression: v)` — mechanically valid, semantically
   absurd (voice channel chained into a calculator). The heuristic
   has no notion that a verb's bound value is meant to be consumed.
   Fix belongs in koru_std: prefer heads whose arm binding is
   consumable, or exclude emit-only verbs from head candidacy.

## The dual-use thesis (still alive)

The same success corpus and guide/trajectory infrastructure serves
two consumers: (a) context assembly for incumbent-style LLM agents
(above), and (b) n-gram draft warm-starting for diffusion models —
the construct-proposal injection proven causal in the n-grams repo,
with diffusiongemma-26B showing real agentic recovery behavior. The
portal's per-turn context view is the observability surface for BOTH
paths; cassette replay (replay states with altered guidance, measure
delta) is the shared evaluation harness. Nothing here forecloses the
diffusion line — it parks until the channel is truthful.

## Watched development — NCM (2026-11-10)

Next-Concept Modeling (arXiv 2610.14162, Stanford Hazy Research,
Kumbong/Khare/Arora/Ré): a multiscale residual-VQ tokenizer represents
text as a coarse-to-fine hierarchy of discrete codes; a frozen-tokenizer
transformer generates one level per forward pass, all positions within
a level in parallel (~8–32 NFEs). Matches/beats diffusion LMs at
10–31× wall-clock, 4–5× fewer training tokens — on benchmarks only
(LM1B, OpenWebText, TinyStories, XSum, WMT14, Sudoku; ≤725M params, no
agentic weights released).

Why it matters to this project, honestly:

- Validates the coarse-to-fine thesis we are already betting on —
  structure committed before detail is a real axis, not a crackpot one.
- Independently confirms the granularity lesson we paid for: BPE
  fragments could not express grounded constructs, so proposals moved
  to construct level. NCM's useful unit also sits above the token.
- The Sudoku result is the closest analogue to our use case:
  coarse-to-fine helps constraint satisfaction — legal wire programs
  are exactly that.
- Its conditioning-code corruption trick is a *trained* version of our
  draft-robustness problem: imperfect priors are the regime, not the
  edge case.
- Speculative thread worth keeping: our 402-trajectory / 5,359-construct
  corpus is the kind of narrow domain data where a custom multiscale-VQ
  could learn construct-level codes generic tokenizers cannot.

Not a backend swap today — no agentic NCM exists, and state()/context
assembly are substrate-independent. Watch-item: if an agentic-scale
NCM appears, this harness tests construct-prior → coarse-code
conditioning on the same trajectories.

## Design session — context assembly v2 (Fable pass, 2026-11-10)

A stronger-model design pass reviewed this proposal against the corpus
and receipts. Its critique was verified claim-by-claim before adoption;
the position below supersedes §3 (surprise-gated guides) and reshapes
item 3 (context assembler).

### Verified facts that killed prior-based surprise

- `n-grams/constructs.jsonl` (5,359 rows) has **no outcome field** —
  keys are `args/arms/doc/src/turn/type/verb`. 5,060 rows unarmed;
  of 299 armed, 268 arm only `ok`. A success-only corpus cannot produce
  "actual vs modal branch" — the surprise score was uncomputable as
  specified. (The `doc` key collapses run dirs — `taskN/trialM/receipts`
  — so 94 distinct docs does NOT refute the 402-trajectory count; 534
  receipt dirs under `bench/results/measure` make it plausible.)
- `koru_std/guide.kz:51-74` harvest **destroys content**: `\n\r\t`→space
  collapse plus silent break at `clean: [4096]u8`. The indented
  multi-line arm shape the grammar teaches cannot survive file-spike
  delivery. Fix direction: wire examples as template OUTPUT (Liquid
  output is not re-scanned, so rendered `{{ u.field }}` survives) + a
  verbatim `raw` region in `src/liquid.zig` (spelling is Lars's) +
  skip TSV, go AST `appended` injection.
- Receipt audit (14 runs, 7,854 call files): 23,553 `result:` lines —
  the `"branch"` KEY is present in all of them, but Fable's recount of
  final receipts shows **9,596/9,596 branch VALUES are `""`** (31
  error-like payloads). This reporting era emitted ordinary outcomes
  only — named branches never reached the prose. CORRECTED 2026-11-10:
  the `(tor,branch)→next` join is NOT parseable from old receipts;
  verb→verb + reward is (reward via `sim.json:reward_info`). Branch
  labels require regeneration on the current binary. Only **110
  `unhandled-branch` reports exist, in 3/14 runs** — exploration rows
  are nearly absent (they predate `state()` and improved reports).
  147,769 era-mixed prose observation lines are skippable noise.
- Task leakage is real: corpus spans all 50 airline task ids;
  `tau2-bench/data/tau2/domains/airline/split_tasks.json` ships
  `train`=30 / `test`=20 / `base`=50. **Held-out set = the 20 `test`
  ids** — guide authoring and prior tables must never see them.

### The replacement design (adopted)

- **Triggers**: fire on *resolution*, not surprise — refusal always;
  unarmed outcome on first occurrence; armed+mismatched always;
  armed+matched silent (except a pre-act guide for the likely next
  mutating verb); **stall** (same construct, no state change —
  computable from `path:`) escalates with different text, never repeat.
- **Once per key per session**, tracked in a **gate-side fired-set
  ledger** (not transcript-scanning — truncation breaks that), storing
  the turn each key fired on.
- **Prior substrate**: outcome-labelled transition table counted from
  gate logs/receipts — `(tor, branch) → next tor` labelled by reward
  including failures. This IS the guide key space: priors become
  generated guide rows compiled into the gate, exposed to templates as
  variables, stamped with a corpus hash. Retrieval, not surprise
  scoring. Rows below a count floor render nothing. Key rows by run
  directory + task + trial or the doc-key collapse repeats.
- **Payload**: hard-capped bytes, compile-time refusal over cap —
  (1) one sentence on outcome meaning, (2) state-derived facts
  (bound/duration/missing — `runtime.affordances`/`obtainvia` already
  derive), (3) next-move line with counts, (4) one wire line from live
  binding names. Rides the gate's existing step report, gate-authored.
  **No canned examples, no trajectory replay in context** (few-shot
  hurt every n-grams arm; corpus phrasing leaking into arg values was
  the measured draft failure).
- **Policy guidance cannot be outcome-taught**: a forbidden cancel
  returns `ok` — outcome triggers only fire after the act. Policy stays
  pre-act guidance.
- **Always-on ruling**: derived (wire rules, declaration lines)
  always-on — "prompt and enforcement are the same bytes"; tuned
  (examples, framing, tool contract) disclosed on refusal edges and on
  approach; external (tau2 policy ~7.6k) **whole and always-on for v1**
  — slicing is the highest-value later experiment and the worst first
  one (confounds everything). *Status: recommended, awaiting Lars
  ruling.*
- **Two learners, not one**: corpus learns across runs; each session's
  model starts blank. Graduation is per-session (fired-set), never
  per-corpus.

### Eval honesty (adopted as requirements)

- Task-split the transition table; the 20 `test` ids are frozen — no
  guide author reads them.
- Hand-tuning is the bigger leak: keep a frozen task set no guide
  author reads + run a second domain with zero domain guides to measure
  the mechanism, not the authoring.
- Noise band ±4–6 (single trial, 29 tasks) exceeds any disclosure
  delta — judge each guide by replay at its own firing sites (does
  next-act distribution change over N samples?), delete if not; live
  boards for headlines only.
- **Placebo arm**: trimmed always-on set, no guides — otherwise "less
  context helps" and "guides help" are one number.
- Manifest per generation: fired keys, bytes per provenance class,
  guide + prior table hashes.

### Build order

1. Outcome-labelled transition table — **amended after Fable re-check**:
   old receipts yield only verb→verb + reward (branch values all empty);
   the `(tor,branch)→next` table requires **regeneration on train-30
   task ids only** with the current binary (the 20 `test` ids stay
   frozen; existing construct pickles were trained across all 50 and
   need a train-30 retrain before any prediction line is evaluated on
   test). Old corpus still gives an opening-move/approach prior and
   failure denominators — but it is a happy-path corpus (31 error-like
   payloads), so "next move with counts" renders nothing until regen.
   Edge-vs-reward is confounded by task difficulty — compare within task.
2. Gate-side guide render on the step report — five triggers; edges
   authored from **current-binary** runs, not retired surfaces.
3. Replay falsifier + placebo arm.
4. Trim always-on: tool contract and examples first, policy last.

### Cuts (v1)

n-gram surprise score, three-depth dial, trajectory replay in context,
durable cross-session graduation, module-resident `guide:add`
(115_063 stays pinned).

### Fable re-check amendments (second pass, 2026-11-10)

- **`call_step` → per-dispatch records**: a one-line chain is one item,
  so `a() | ok u |> b()` must yield one record per dispatch (or nested
  `dispatches[]`) — per-step loses inner dispatches. Add `armed` (the
  arm words the model wrote — without them bare vs armed-mismatch is
  indistinguishable and prediction accuracy unscoreable). Outcome enum
  must be DERIVED from bridge kinds, not hand-listed — add
  `shape-error`, `event-denied`, `dispatch-error`, `scope-not-found`
  (`bridge.runsteps.kz:99-129`). `handles` normalizes to a name list
  (count on `result`, string on `unhandled-branch`). Also: fired guide
  keys (facts, not derivations), per-arg reference-vs-literal flag,
  state hash per turn (stall detection + replay addressing), `trial`
  + gate binary hash in `run_start`.
- **Placement**: emit at the bridge, not the gate's status printer —
  `tau-agent` (no external gate, produced the old receipts) must log
  the same records. Render the model-facing prose FROM the record so
  log and model view cannot disagree.
- **v1 survives on verb→verb + reward for the MECHANISM** (triggers
  need no priors — computed from live gate state); the consequence map
  waits for regen. Old corpus is happy-path: opening-move/approach
  prior + failure denominators only.
- **Stall correction (Fable's own error)**: `path:` is per-item
  dispatches; stall ran across turns — needs session-level history,
  which the fired-set ledger holds.
- **Policy**: unchanged whole+always-on. Allowed v1 refinement
  (additive): one-line pre-act pointer on approach to mutating verbs,
  measured against the placebo arm.
- **Diffusion carry-back**: neither corpus as posed — retrain on the
  `call_step` stream with branch as a history symbol, backing off to
  outcome-free counts where sparse; the edge table becomes its order-1
  projection (one source, both lines). Wait for regenerated corpus:
  `note` is 1,891/5,359 constructs and colon-era spellings persist.

### Emission design (concrete, 2026-11-10 — implementation in flight)

Field-by-field source map, verified against current tree:

| `call_step` field | source |
|---|---|
| `seq` | `Bridge.call_seq`, ++ per emitted record |
| `turn` | `Bridge.turn_count`, ++ per `run` call |
| `step`,`of` | item index/total — `runSteps` loop / 1,1 single-item |
| `outcome` | item verdict kind, mapped from the `Runtime.run_event.Output` variant (`result`,`unhandled-branch`,`exhausted`,`parse-error`,`validation-error`,`shape-error`,`event-denied`,`dispatch-error`,`scope-not-found`,`abandoned`,`residue`,`defined`,`partial`) — same string the prose line leads with |
| `state_hash` | FNV-1a over sorted `name=<json>` durable bindings + held handle ids + defined names + `bound_count` + scope, computed once per `run` call |
| `verb` | `TraceEntry.event` (qualified tor name) |
| `args` | JSON `[{name,raw,value,ref}]` — raw = pre-eval `inv.args[i].value`, value = post-eval, ref = unquoted non-literal classifier (`true/false/null`/numeric/quoted → literal; bare ident, field path, or expression → reference) |
| `armed` | JSON `[{w,b,g}]` from `flow.body.continuations` at the dispatch node — arm word, binding, `when` guard |
| `arm_word`,`arm_name` | matched continuation's `.branch` / `.binding` (existing `TraceEntry.arm` is the binding) |
| `branch`,`payload` | `dispatch_result.branch` / existing `TraceEntry.json` |
| `bound` | existing `TraceEntry.bound` (rN) |
| `handles` | `renderHeldHandles(pool)` JSON list snapshot post-dispatch |
| `used` | `event_cost` charged for that dispatch |
| `fired_guides` | `[]` until guides exist |
| `failed`,`error` | set on the dispatch that threw (see pending-step below) |

Mechanism:

- **`TraceEntry` IS the record.** Extended in `interpreter.trace.kz` with
  the new fields; `renderTrace` (prose) and the new JSONL renderer read the
  same entries — log and model view cannot disagree by construction.
- **Capture site**: `executeFlow` dispatch block (`interpreter.run.kz`
  ~826-861). Args/armed JSON built pre-dispatch; a `ctx.pending_step`
  stash covers the throwing dispatch so `dispatch-error` tails still emit
  a record (`failed:true`). Defined-flow calls record like any dispatch;
  their inner body calls record as their own entries.
- **Escape**: threadlocal trace sink (same pattern as
  `setRunMountedScopes`/`setDispatchPool`) flushed by `run|zig` before
  each trace-carrying return; `dispatchThroughScope` sets/reads/clears
  per item and returns `{out, steps}` — arena slices stay valid until the
  next interpreter run, and serialization happens inside the per-item
  loop before any subsequent dispatch.
- **Bridge accumulation**: `call_log` JSONL on `Bridge` (session arena),
  drained by new tor `take-calls -> string`. No `run` tor signature
  change — ~45 call sites untouched; consumers opt in by draining.
- **Gate**: `handle` splits into report + `settle`; `settle` drains
  `take-calls` and emits `CALLSTEPS-BEGIN/END` framed block (STEPS
  precedent) only when non-empty. `tau_gate_session` parses it;
  `airline_llada_agent` emits one `call_step` runlog event per JSONL
  line. `tau-agent.k` drains to `eprint` marker (its runlog path is the
  legacy receipt producer — follow-up).
- **`run_start`**: `trial` + gate binary hash added harness-side.

Known v1 gaps (declared, not hidden): arg-eval failures (`UnboundName`,
`FieldNotOnBoundValue`) throw before `pending_step` is armed — those
dispatches produce no record (item outcome still records
`dispatch-error`); `exhausted`/`parse-error`/`validation-error`/
`residue`/`defined` items dispatch nothing and emit no records.

### Open questions carried forward

- Policy slicing: whole+always-on v1 recommended; slicing deferred to
  placebo-controlled experiment. **Awaiting Lars ruling.**
- Observation channel is Python-authored (`result:`/`user:`/prefixes in
  flat role:user) — a live frame-law surface; guide payloads must be
  gate-authored content through that plumbing, and the channel itself
  is a separate cleanup.
- **Diffusion carry-back (parked)**: when the n-gram line unparks,
  should priors retrain on the outcome-labelled edge table rather than
  the outcome-free construct corpus? Tag Fable for this + held-out
  confirmation when context assembly lands.

## Migration note

Bench research scripts already live in bench/ (untracked). n-grams
keeps corpus building, n-gram training, and diffusion eval. This repo
owns: the gate/harness, runlog, portal, smart tools, guide mining.

## Say-protocol desync — RESOLVED 2026-11-10

Phase 1 measured (gate_probe vs both binaries, 2026-11-09):
oct2 12/13, rebuilt 11/13 — bare-call HALT is a std/bridge semantic
change; arm-chain FAIL was a stale STEPS expectation.

Phase 2 root-caused and fixed (2026-11-10):

- **Residue mechanism confirmed deterministically.** gate_intake.kz
  has NO kind dispatch: `intake` reads first line + continuation
  until blank and treats ALL of it as wire text. A `{"kind":"user"}`
  line written while the gate sits at intake becomes the first line
  of the next turn — glued in as a residue item (visible verbatim in
  run 181050's STEPS reports: `step 1/3 residue bound: r3 —
  '{"kind": "user", "text": "No problem…' is not wire`). Pinned by
  gate_probe's trap case.
- **The gate never wants user lines.** airline-gate.k's serve loop is
  intake → bridge:run → status, full stop. pull()/take-pending exist
  in tau_wire.kz for tau-agent.k's all-Koru loop, which the gate
  never calls. Say-debt (outstanding_user) is inert here. User
  replies are transcript-level: tau2 user sim → UserMessage →
  _ingest → next generation's context. They never enter the gate.
- **TauGateSession rewritten**: `_await` is now "call" (blocked in
  callIO — feed_result is the only legal write) | "say" (gate running
  — read-only via next_event()) | None (at intake — send_wire legal).
  feed_user deleted.
- **Ruling: unarmed-outcome HALT stays.** Explicit arms beat implicit
  auto-binding — honest, self-teaching (the gate's report literally
  says `to keep going, arm it | ok name |>`), fail-loud consistent.
  Fetch primitive = `call | ok r |>`.
- **Agent observation fixes**: say-bound OK details no longer echo
  the agent's own say text as `user:` (sayIO returns emitted text —
  the old code labelled it a user reply, amplifying the "I can't
  access…" loop); STEPS non-result lines (unhandled-branch, residue,
  dispatch-error) now reach the model verbatim instead of being
  mangled into `result:` noise.
- **Item count = line count** (pinned): arm chain on one line = 1
  item → OK; same chain across two lines = 2 items → STEPS. Unarmed
  outcome: single-item → HALT; multi-item → per-step
  `unhandled-branch:` line, siblings continue.
- **gate_probe.py rewritten**: 18 cases, exact event-sequence
  assertions, multi-turn session pins (residue only manifests
  turn-over-turn), say-arm-binds-emitted-text pin, trap pin.
  **18/18 green on airline-gate-binary.**

### Fable landed-schema re-check (third pass, 2026-11-11)

Schema ACCEPTED with one rename + three fixes + one invariant. Verified
against the live trial log himself.

- **Rename**: `outcome` → `item_outcome` (item verdict, not dispatch
  fate — a per-dispatch `outcome` gets miscounted in chains). DONE in
  bridge.calls.kz; downstream passes dicts through, no Python change.
- **state_hash stays as replay address only** — it CAN'T detect stalls:
  every dispatch mints rN so identical calls hash differently (4
  identical failing calls → 4 hashes, verified). Stall detection moves
  to analysis-side call-identity comparison (verb, resolved args,
  branch, payload) vs session history; gate-side ledger can hold it
  at runtime later.
- **FIX: item coverage invariant** — every item yields ≥1 record,
  including zero-dispatch items (residue, parse-error, defined,
  validation-error, event-denied). Live proof of the hole: turns
  reported `of: 2` but step 2 (a say failing on unbound `u` —
  UnboundName arg-eval throw) produced no record.
- **FIX: UnboundName/arg-eval failures must record** — refusals are
  the "always fire" trigger class; an unrecorded refusal is a missing
  guide site. Fix = arm pending_step BEFORE arg eval (defer args-JSON
  build to appendPendingStep via stored arg slices; recordFailedStep
  renders raw+ref with value="" since eval didn't complete).
- **FIX: origin marker** — harness-issued calls (agent init grammar()
  etc.) indistinguishable from model wire. Caller-side tagging:
  AirlineLladaAgent stamps origin="harness"|"model" at drain time.
- **FIX: run_start** — add `trial` + `seed` (gate_sha landed).
- **NEW gate_probe case** (Fable-specified): assert distinct
  (turn, step) pairs in records == `of` coverage for a turn mixing
  refusal + chain + unbound name; fix what it turns red.
- Dispatch fate needs NO new field — derivable from
  failed/armed/arm_word (his table verified).
- Diffusion carry-back STANDS with conditions: history symbol is
  dispatch-level (verb, branch, fate) never item_outcome; filter
  harness records; train-30 only. Still waits on volume.
- Policy: Fable says enough exists to rule whole+always-on v1 —
  Lars's ruling, still open.

## Escalation ladder — surprise-routed model tiers (design session, 2026-11-11)

Lars + Devin design dialogue. Extends the guide layer from "computed
context" to "computed context + routed inference": surprise becomes
the router between model tiers, and the strong model's output at a
surprise site feeds back into the periphery as a candidate lesson.

### The tier stack

- **T0 — algorithmic**: gate, transition priors, guide lookups, stall
  detection. Free, always on, zero inference.
- **T1 — cheap diffusion**: mini/26B-class + construct drafts +
  assembled context. Routine wire, the ~95%.
- **T2 — strong inference**: fires only on surprise. Packet is SMALL
  by construction — `state()` snapshot, diverging edge, live bindings,
  prior-vs-actual, guide payload — never the whole trajectory.
  Context assembly pays twice: it feeds T1 and packages the escalation.
- **T3 — human**: policy calls, genuinely novel situations, taste —
  the residue even T2 can't justify.

### Why this is RSI and not just routing

The unit of improvement is the system (model + periphery + corpus),
not the NN — weights stay frozen; what improves is explicit structure.
Concrete surfaces already in flight: call_step → transition table →
outcome-labelled priors → guide rows → better next run; cassette
replay as the self-modification verifier; vocabulary/register blocks
as capability declarations; zlow schema evolution (stretch) as
self-modifying pipelines; the membrane as the epistemic layer.

The T2 write-back is the load-bearing new piece: a strong model's
answer at a surprise site produces (a) the next action AND (b) a
candidate lesson → cassette replay → promote to guide row /
transition-table entry / vocabulary patch. The expensive model teaches
the cheap system; the lesson persists in algorithmic space.
"Distill into C" becomes "distill into the periphery" — HOC's insight
on a substrate that exists. Measurable claim: surprise rate and
escalation rate on held-out tasks decline as coverage grows.

### Honest caveats (declared, not hidden)

- Escalated output faces the same gate/`koruc` verification — T2 is
  still periphery; the trusted core stays trusted.
- Promotion needs the same eval honesty as guide authoring: held-out
  test ids, placebo arm, replay at firing sites — else we distill the
  strong model's errors into the periphery.
- Epsilon (surprise threshold) IS the spend dial — T2 prices are only
  viable because routine turns never pay them.
- Latency is acceptable: agentic tasks are correctness-bound and the
  divergence path already returns control by design.

### Relation to human-in-the-loop

Not competitors — tiers of the same ladder. T2 absorbs the computable
residue at machine prices; T3 keeps policy/judgment/taste. Every
escalation is never wasted: a human answer becomes a guide lesson +
corpus row + outcome labels — help-now AND training data. Per-session
graduation stays per-session (model starts blank); corpus-level
coverage growth is the cross-session version of "needs less
intervention."

### Generalization claim + falsifier

Mechanism is domain-general (armed-vs-actual, stall, unarmed outcomes
need zero corpus — any Koru program gets the loop free); knowledge is
domain-local by design (facts stay local, patterns go global via
wildcard guides `* -> error` and shared anomaly classes). Open domains
degrade gracefully: sparse priors → common early surprise → every
escalation is corpus data → coverage grows → surprise rate declines.
Permanent heavy tail = genuinely novel situations, which is where new
vocabulary comes from — not a flaw.

Falsifier: surprise/escalation rate on held-out NOVEL tasks must
decline as outcome-labelled coverage grows — measured on a second
domain vocabulary with zero domain guides, alongside the airline
replay tests. If escalation rate doesn't decay with coverage, the
"general tasks" version of the claim is dead and the system is a
repeatable-workflow tool only.

### Build-order placement

Slots between current items 2 (gate-side guide render) and 3 (replay
falsifier + placebo): the escalation packet format is an extension of
the guide payload; the write-back path reuses the cassette harness;
the tier router consumes the same trigger classes. No new machinery —
a new consumer of existing surfaces.

## Commission-2 deltas — the real trees (2026-11-11, Devin + Fable output-2)

Two organize-only passes over the corpus (Fable 5.2; outputs at
`n-grams/fable-pack/output/` and `output-2/`). Commission 2 read the
actual zlow `src/` tree and 6digit-world engine/CLI/models — three
load-bearing citations spot-verified against live trees by Devin
(`pipeline.ts:462` flow.ran re-entry bar, `wm.mjs` dead route
declaration, `cassette.ts:70-79` key shape — all confirmed).

Build-order deltas (R0–R11 stand; these amend):

- **R5 re-scoped — easier.** zlow `src/cassette/cassette.ts` is a
  working N-sample record/replay keyed on full call inputs
  (`{model,system,temp,prompt,schema}` → guide-present vs guide-absent
  are naturally separate recordings) + `variance.ts` invariant checks.
  R5 is now "the Koru-wire instance of a proven pattern," not "the
  ecosystem's first replay instrument." Still missing: trajectory-level
  replay (zlow variance is per-step by design).
- **R8 re-scoped — easier conceptually.** The T0–T3 escalation shape
  already exists in `zlow/src/fixtures/dispatchLoop.ts` (algorithmic
  guard → fast fill → capable escalation → park-for-human) with named
  tests. Work = porting semantics onto the Koru gate, not inventing
  routing. Two constraints to carry into spec: `emit$on` fires on
  truthy presence only (surprise classes need per-class booleans or a
  handler step); `flow.ran` bars re-entry (the agent loop stays
  host-driven — zlow hosts per-turn pipeline, not the cycle).
- **N1 — WMFX scoreboard instrument (new, unblocks `03` §6 dark
  rows).** `models/kopium_scoreboard/`: producer reduces committed
  `call_step` corpus → `data/series.csv` (one row per generation:
  surprise-by-class, silent-fail, edge coverage, reward);
  `model.wmfx` = 019-style drift envelope; oracle/run/split.json per
  the 013 template; replay-first, live-tick second (dirty_tree
  pattern). Depends on R3's regenerated corpus. Honest split:
  counts are producer columns/tests; trends are `.wmfx` models.
- **N2 — zlow per-turn spike (optional de-risk for R8).**
  `surpriseGate` handler step + `escalate` capable step proving
  trigger→assembled-context→cassette-replay with zero Koru code.
- **N3 — dead route-line warning.** `.signal` `route:`/`wmfx=` lines
  are DEAD DECLARATION (`wm.mjs:1448-1453`); live routing is NATS
  JetStream via `tick.json` `filter_subjects`. Any KOPIUM signal
  wiring must use tick.json subjects, never the .signal route line.
- **Sibling-authority guardrail.** Koru gate = legality (authoritative
  oracle); zlow = per-turn pipeline + cassette replay + trace;
  WMFX = watcher. Wire at edges (zlow trace → WMFX producer; zlow
  cassette → replay falsifier; judge-gate Sample → WMFX port).
  Any proposal to let zlow validate wire or WMFX decide escalation is
  the thesis-merge anti-pattern — flag it, don't build it.
- **zlow verdict upgraded:** more than a mocked skeleton — cassette
  N-sample replay, variance checker, durable park/resume, trace
  stores, judge-gate/vector, dispatch fixture all real code; "all
  tests passing" unverified (cassette dir absent from corpus, no runs).
  Thesis (cost reduction on real workload) still unmeasured.
- **WMFX verdict narrowed:** engine real (7,267-line Zig, golden suite
  wired); Phase-2 live-tick half EXISTS (`models/dirty_tree` tick +
  build-tick); what's unbuilt is consumers/wiring + any KOPIUM
  instrument — zero grep hits for kopium/call_step/n-gram/tau2 in the
  whole tree.
