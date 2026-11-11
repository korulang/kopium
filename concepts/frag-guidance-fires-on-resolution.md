---
type: belief
id: frag-guidance-fires-on-resolution
provenance: Fable design pass on PROPOSAL-context-assembly.md +
  verified audit of constructs.jsonl and bench/results/measure
  receipts, 2026-11-10
ts: 2026-11-10
tags: [kopium, guides, context-assembly, priors, corpus]
---

# Guidance fires on resolution, not prediction-violation — and priors
# need outcome labels to teach consequence (belief)

Outcome-triggered guidance fires when a branch *resolves* — refusal,
unarmed outcome, armed-mismatch, stall — once per key per session via a
gate-side fired-set ledger. Refinement (Lars ruling, 2026-11-11): these
triggers ARE surprise-firing in event form — armed-mismatch is the
model's own written prediction (`| ok r |>` predicts ok) violated by
the gate's verdict, computable with zero corpus; unarmed outcome is a
topology surprise; stall is a dynamics surprise. What was never
computable *on the corpus that existed* is the graded magnitude —
"actual vs modal branch" needs outcome labels the construct corpus
lacks (5,060 of 5,359 rows unarmed; armed rows predict `ok` only). That
dial returns when the outcome-labelled `(tor,branch)→next` transition
table regenerates — an order-1 Markov chain over the program's
control-flow graph, shared with the diffusion line's order-1
projection. Resolution triggers are surprise with cheaper prediction
sources, not its replacement.

The deeper ruling: **a corpus without outcome labels teaches wire
shape, never consequence.** Any prior substrate meant to guide or
score must be outcome-labelled — which is why the prior source moved
from construct n-grams to a `(tor, branch) → next tor` transition table
harvested from receipts (23,553/23,553 `result:` lines verified to
carry `"branch"`; reward joins via `sim.json:reward_info`).

Two learners stay distinct: the corpus learns across runs; each
session's model starts blank. Graduation is per-session (the fired-set),
never per-corpus — "priors sharpen so guides fade" was a category error.

What would correct this: an outcome-labelled construct corpus making
true surprise-scoring computable *and* beating resolution-triggers in
replay at their own firing sites; or evidence that resolution-triggered
guides underperform prediction-violation triggers on identical states.
