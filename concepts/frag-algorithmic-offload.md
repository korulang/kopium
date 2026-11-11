---
type: belief
id: frag-algorithmic-offload
provenance: Devin session — Victor Taelin/HOC post discussion mapped
  against n-grams + kopium + zlow, 2026-11-11
ts: 2026-11-11
tags: [kopium, context-assembly, algorithmic-offload, zlow, n-grams, thesis]
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

Already-absorbed correction (frag-guidance-fires-on-resolution):
surprise-gating died on evidence — the construct corpus carries no
outcome field, so "actual vs modal" was uncomputable. Resolution+stall
triggers fed by an outcome-labelled `(tor,branch)→next` transition
table replaced it. Priors are retrieval tables, not surprise scores;
two learners stay distinct (corpus across runs, model blank per
session, graduation per-session via fired-set).

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

Pointers (mechanics live there, not here): `PROPOSAL-context-assembly.md`
(the build), `n-grams/rd.md` (the lab notebook), `~/src/zlow/DESIGN.md`
(the orchestration altitude).
