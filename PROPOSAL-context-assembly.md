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
