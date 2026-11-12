---
type: belief
id: frag-exemplar-attractor-limit
provenance: live thread 2026-11-12 — task-10 arm-C rerun, exemplars verified
  firing in request bodies yet collapse survived to FATAL; external review
  caught the earlier null-experiment claim
ts: 2026-11-12
---

# Exemplars teach recovery, not attractor escape

A demonstrated failure->error->correction exchange injected into context
(in boot seed or at strike-time, verified firing in request bodies) does
NOT break a collapsed generation attractor. On tau2 task-10 the model
received the say() recovery exemplar after every refused reply — visible
in call_*.json — and still emitted prose until the 10-strike bound killed
the run.

The distinction that matters: exemplars transfer *recovery mappings*
(error X -> do Y) to a model that is still choosing its actions. They
cannot transfer *mode escape* — a model that has fallen into narration or
a repeated-error loop is no longer choosing among the demonstrated
options; it is inside one. The fix for that class is not a better
exemplar but a different failure-class treatment: positional doctrine at
the dispatch that caused it (the get-reservation-details->error guide
gained the placeholder-arg lesson after task-10 invented
"your_reservation_id"), or enforcement that removes the choice entirely.

Open question: where the boundary sits — which failure classes are
attractor-escape (need enforcement/structure) vs mapping-gaps (exemplars
suffice). Task-3's nested-field loop was mapping-gap-adjacent and died
with the invalid demo path removed; task-10's was attractor and survived
every exemplar.
