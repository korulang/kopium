---
type: belief
id: frag-opaque-handles
provenance: Lars ruling 2026-09-07 (re-ruled 2026-09-08, encoded as a wall case)
ts: 2026-09-08
---

# Handles are opaque; prediction-as-mechanism is the banned shape

A freshly minted handle is 6 lowercase hex, mixed from a per-process seed —
not `note_N`, not sequential, not guessable. The only legal access is
BINDING what an observation returned; a fabricated name dies at the pool
(`HandleNotHeld`, pre-proc). This kills the entire cheat class: hardcoded
probes, canned models that append a predicted name, any test that assumes
the mint. Nothing to predict, nowhere to miscount.

Ruled 2026-09-07 after the session analyzed `note_0` — predictable names are
a lying affordance: the counter is process-global and never reuses, so a
second session's first open mints `note_1`, and a model counting opens holds
a mental model that is wrong in exactly the multi-session case. Re-ruled
2026-09-08 when the analysis had produced no change — which is the lesson
this fragment also owns: a ruling is not real until it is a failing test.
It is now: the `opaque-handles` wall case pins mint shape, non-sequentiality,
binding-works, fabrication-refused.

Enforcement never depended on secrecy — the pool is the authority — so
opacity adds no safety. It buys HONESTY OF ACCESS: the surface can no longer
pretend handles are knowable. Consequences: probes, canned sessions, and the
prompt examples bind (`open(...) | ok h |> append(handle: h, ...)`);
`last-minted` is the inspection seam for canned sessions, deliberately
absent from the agent's register (a handle is never something to ask for —
it is something you were given).

What would correct this: a measured replay showing opaque handles meaningfully
hurt live task completion (models bind worse than they predicted), or a ruling
that readability outranks the cheat-class kill. Until then: binding is the
only legal access.
