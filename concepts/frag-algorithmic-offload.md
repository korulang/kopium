---
type: belief
id: frag-algorithmic-offload
provenance: Devin session — Victor Taelin/HOC post discussion mapped
  against n-grams + kopium + zlow, 2026-11-11
ts: 2026-11-11
tags: [kopium, context-assembly, algorithmic-offload, zlow, n-grams, wmfx, surprise, thesis]
---

# Algorithmic offload is one thesis at three altitudes (belief)

The work spanning `~/src/n-grams`, this repo, and `~/src/zlow` is a
single move: relocate everything computable out of latent space into
algorithmic space, and reserve inference for judgment. zlow does it at
orchestration altitude (schema seam — routing, extensions, context
assembly algorithmic; one schema fill per step latent). KOPIUM does it
at context altitude (`state()` read, guide table, outcome-labelled
transition priors, resolution/stall triggers — computed context, not
system-prompt prose). n-grams does it inside generation (construct
drafts so the denoiser spends fewer steps; parked pending capacity).

The enabling condition is domain closure: enumerable ⇒ countable ⇒
compilable ⇒ testable. Schema vocabularies, tor/branch topology,
construct productions are all enumerable; open-domain chat has no
enumerable state to compute against. That is the same boundary as the
n-grams form-vs-facts wall, seen from a third angle — frequency
methods supply shape wherever the shape-space is closed, and stall at
grounding wherever it isn't.

Correction absorbed, then refined (frag-guidance-fires-on-resolution,
then Lars's 2026-11-11 ruling): what died on evidence was ONE
substrate — the graded surprise score against an outcome-free
construct corpus (5,060/5,359 unarmed; no modal to compare against).
Surprise itself survived in three computable forms: armed-vs-actual
(the armed branch IS the model's written prediction; gate verdicts
supply the outcome, zero corpus needed — the adopted "armed+mismatch"
trigger IS surprise-firing), stall (session-level, fired-set ledger),
and unarmed outcomes (declared topology didn't cover what happened).
The distributional dial — how surprising is this edge empirically —
waits on the outcome-labelled `(tor,branch)→next` transition table,
which IS an order-1 Markov chain over the program's control-flow graph
and doubles as the diffusion line's order-1 projection (one source,
both consumers). Resolution triggers are surprise with cheaper
prediction sources, not its replacement. Two learners stay distinct:
corpus across runs, model blank per session, graduation per-session
via fired-set.

The control loop underneath all of it is WMFX's, unchanged: predict →
observe → gap → route attention. Koru's declared state machine makes
the world model free — world, model, and sensor are the same artifact
(tors=states, branches=edges, call_step records=the transition log).
Guide payloads are interrupts; the fired-set is the refractory period;
guide:add(tor->branch){lesson} is the discover→capture→watch ratchet
compiled into the periphery. zlow instantiates the same loop at the
pipeline seam (schema=prediction, output=reality, validation failure=
flinch). Surprise is not a feature of this system; it is the question
the algorithmic periphery exists to answer.

The HOC/TAELIN connection — why this fragment exists: HOC's bet is
*discovering* a raw program observationally identical to a NN, via
program search at maximum difficulty, bottlenecked on "we cannot train
raw programs." This project's bet is *designing* the algorithmic
parts and shrinking the latent residue — no discovery needed for
everything enumerable. His irreducible remainder (judgment,
grounding, anything not recoverable from enumerable state) is our
latent residue; seam-drawing is the research on both sides.

What would correct this: replay evidence that guide/transition priors
don't shift next-act distributions at their firing sites (the adopted
eval tests exactly this); evidence the latent residue can't shrink —
assembled context failing held-out tasks against the always-on
prompt + placebo arm; or algorithmic parts silently requiring latent
judgment (schema-design failures dominating outcomes). The framing
itself is a stance, not a measurement — the measurements live in
PROPOSAL-context-assembly.md's replay harness and n-grams/rd.md.

Sibling authorities (2026-11-11, commission-2 ground-truth pass): the
three projects are siblings with distinct authorities, wired at edges —
never merged into one oracle. Koru gate = legality (authoritative);
zlow = per-turn pipeline + cassette replay + trace (its dispatchLoop
fixture already proves the T0–T3 escalation shape); WMFX = watcher
(its dirty_tree live-tick pattern is the template for watching
call_step-derived series). A proposal that lets zlow validate wire or
WMFX decide escalation is the thesis-merge anti-pattern. Trap recorded:
`.signal` route lines are dead declarations — live routing is NATS via
tick.json filter_subjects.

Pointers (mechanics live there, not here): `PROPOSAL-context-assembly.md`
(the build), `n-grams/rd.md` (the lab notebook), `~/src/zlow/DESIGN.md`
(the orchestration altitude), `n-grams/fable-pack/output-2/` (the
code-level ground truth).
