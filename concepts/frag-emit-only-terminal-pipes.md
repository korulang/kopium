---
type: belief
id: frag-emit-only-terminal-pipes
ts: 2026-11-15
tags: [kopium, wire, semantics, probes, say, note]
provenance: TauGateSession probes 2026-11-15 closing matrix cell #4 —
  say/note pipe behavior verified after contract text taught it wrong
---

# frag-emit-only-terminal-pipes

**Belief:** emit-only tors (`say`, `note`) are pipeline *terminals* in
the wire language. They may receive `|>` input (the canonical
`call | found u |> say(...)` shape) and may take an outcome arm
(`say(...) | ok x |>` binds the emitted text) — but they can never emit
`|>` forward, because they produce no pipeable result. `say|>next` is a
parse-level rejection, not a style rule.

**Why:** the deleted contract blob taught "never append a continuation
arrow *or outcome arm* to say" — half right, half wrong. The arm is legal
and meaningful (it binds emitted text, per gate_probe's own docstring).
Teaching surface that contradicts the language doesn't just fail to
help — it trains the model to avoid a legal shape while still committing
the illegal one, because the real rule was never stated precisely.

**Open questions:** does `|>` pipe *data* or *sequence* for result-bearing
calls (cell #5, still open — Fable's interpreter audit)? Do other
emit-only verbs exist beyond say/note, and is "terminal" a declared
property or an emergent one of void returns?
