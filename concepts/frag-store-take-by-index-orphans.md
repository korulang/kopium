---
type: belief
id: frag-store-take-by-index-orphans
provenance: headed.k live debugging, 2026-09-11 — frozen ESTABLISHED sockets as the witness
ts: 2026-09-11
---

# A store take is deferred — `take(store[0])` by index orphans the live row

The 2026-08-07 headed.k header already measured the half of this: "the
take happens a tick after the insert, so two rows coexist." The other
half, proven today: because a take lands late, a `fire()` that retires
row 0 and inserts a new pending in the SAME tick puts the new row at the
next free slot ([1], not [0]). Every later `take(batch[0])` hits the
slot that is already gone — `| empty` — and the live row is orphaned
forever: never polled, never retired, never cancelled. The witness was
two transfers stuck ESTABLISHED at frozen byte counts while the UI
believed them dead.

This is the "capacity-2 stores ACCUMULATE" ghost resolved to a rule:
**take by the row the insert reported, never by index.** `insert`'s
`| row rh` result is the only honest handle; `d_turns.k` tracked it as
`ui.brow` and the headed rewrite dropped it — restoring `brow` was the
fix, not another lifecycle guess.

The same shape sinks any consumer that treats store rows as a
zero-indexed stack: rows are slots, take is deferred, and index 0 is a
guess that is wrong exactly when the store is busiest.
