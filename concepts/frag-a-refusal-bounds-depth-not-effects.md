---
type: belief
id: frag-a-refusal-bounds-depth-not-effects
provenance: live-define self-referencing-redefine replay 2026-10-03 —
  the depth cap refused `jot` and the disk held 64 appends
ts: 2026-10-03
---

# A dispatch refusal bounds the runaway, not the effects — recursion is not a transaction

A defined flow refused at the dispatch depth cap answers the failure by
name — but every nested dispatch that ran before the refusal already
produced its side effects. Measured live: a self-referencing `jot`
(append-then-recurse) filed **64 copies** of the same entry before the
cap answered. The refusal is a verdict on the *result*, not a rollback;
the file holds a cap-depth scar either way.

Two consequences that are easy to miss:

- **Refusal wording must not overclaim.** `REFUSED ... 'jot' never ran`
  describes the result correctly and the history falsely — the body ran
  64 times. A refusal line that says "never ran" is the dishonest half
  of an honest failure.
- **The cap bounds depth, not damage.** A defined flow that mutates
  before recursing leaves cap-depth destruction. That is the correct
  shape (unbounded recursion is a refusal, not a feature — and a refusal
  is not a transaction), but anyone modeling "the refusal kept the world
  safe" is wrong by up to 64 mutations.

Related: [[frag-partial-programs]] — same non-atomicity one level up: the
steps that ran before a refusal are durable there too. The open question
both share: whether the surface needs a *transactional* rung (a run that
rolls back on refusal) or whether honest wording is enough.
