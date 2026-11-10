---
type: belief
id: frag-bindings-scope-in-three-layers
provenance: kopium state() build 2026-11-10 — measured on the rebuilt
  airline gate; single-item turns pass turn_env=null (bridge.run-exec),
  so a one-line `call | ok u |>` binds u into the run env only; the
  turn layer exists solely for multi-item turns (bridge.runsteps)
ts: 2026-11-10
tags: [kopium, wire, bindings, state, scopes, introspection]
---

# Bindings scope in three layers — durable, turn, item (belief)

A bound name is not just "bound" — it is bound *somewhere*, and the
somewhere decides how long it lives. `state()` renders all three
layers labeled, because collapsing them lies:

- **durable** — `session_env`: `rN` auto-binds and `bind()` names.
  Survives every turn. This is the only layer `vocabulary()` shows
  (names + field shapes, never values).
- **turn** — `turn_env`: `| ok u |>` arm names bound by earlier items
  of a MULTI-ITEM turn, visible to later items. Dies at turn end.
  Single-item turns have no turn env at all — `dispatchThroughScope`
  is called with `turn_env=null` on that path.
- **item** — the run env: whatever THIS item bound and neither layer
  above claimed. A one-line `call | ok u |> state()` binds `u` here —
  resolvable for the rest of the chain, gone when the item ends.

The measured surprise that forced the third layer: we first shipped
`state()` showing only durable+turn, and the chained probe showed
`turn: (none)` while `u` was plainly resolvable — the arm had landed
in the run env, which no introspection surface exposed. The env is
seeded with copies of both durable layers, so the honest render diffs:
run-env names absent from session_env and turn_env are the item's own.

The deeper belief: scope is data, not prose. A prompt that says "u is
bound" without saying *for how long* teaches a lie the model cannot
detect — `state()` exists so the lifetime claim is checkable, the same
reason arms are mandatory rather than implied.
