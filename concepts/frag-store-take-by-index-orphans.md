---
type: belief
id: frag-store-take-by-index-orphans
provenance: headed.k live debugging 2026-09-11; mechanism CORRECTED same day against hole 3's tail note + the emitted __koru_resolve
ts: 2026-09-11
---

# `take(store[0])` by literal is a permanent no-op — rows are handles, not indices

Store rows are addressed by the row handle `insert` reports (`| row rh`),
an opaque `slot | brand<<24 | gen<<32` value. A literal `0` has brand 0,
which no minted handle ever carries — so `take(batch[0])` compiles clean
and yields `| empty` on EVERY call, at any store state. This was already
documented at the tail of hole 3's HOLE.md (pinned shape `take(game[r])`,
690_024; handle layout 690_196) and re-derived the hard way when the
headed agent's `retire` silently took nothing: the capacity-2 `batch`
accumulated a row per turn, turn 3's insert hit `| full`, the transfer
was cancelled while `ui.live` stayed 1 — the "turn 3 hangs" ghost in
full. The witness was two transfers stuck ESTABLISHED at frozen byte
counts while the UI believed them dead.

CORRECTION to this file's first writing: the orphaning was blamed on a
deferred take racing an insert ("the new row lands at [1] while [0] is
still being freed"). Wrong mechanism — the take never had a chance; a
literal index is never a handle. The same correction reaches further
back: the 2026-08-07 header's "the take happens a tick after the insert,
so two rows coexist" was probably THIS bug misread as a timing issue —
`drop-framer`'s `take(framer[0])` was also literal-0, also a permanent
no-op, and the doubled deltas ("saysay") were two never-removed framers
swept by `! query`, not a lagging take. Whether store takes are deferred
AT ALL is now unmeasured; nobody has seen one land late, only never.

The rule stands stronger than first written: **take by the row the
insert reported, always** — `stored { ui.brow: rh }` on `| row`, then
`take(batch[ui.brow])`. `d_turns.k` always had it; the headed rewrite
dropped it, and restoring it — not a lifecycle guess — is what un-wedged
the head.

Floated to the store surface (hole 3's tail already said it): a literal
argument to a handle-addressed head arguably deserves KORU161 at compile
time instead of silent `| empty` — the current shape makes the no-op
invisible until the store fills.
