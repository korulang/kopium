---
type: belief
id: frag-emit-only-terminal-pipes
ts: 2026-11-15
tags: [kopium, wire, semantics, probes, say, note]
provenance: TauGateSession probes 2026-11-15 closing matrix cell #4 —
  say/note pipe behavior verified after contract text taught it wrong;
  evolved same day by bench/probe_pipe_semantics.py (cells #5, #6)
---

# frag-emit-only-terminal-pipes

**Belief:** emit-only tors (`say`, `note`) are pipeline *terminals* in
the wire language. They may receive `|>` input (the canonical
`call | found u |> say(...)` shape) but can never emit `|>` forward,
because they produce no pipeable result. `say|>next` is a parse-level
rejection, not a style rule. And `|>` never carries data on its own for
any call: a bare `|>` after a call is refused at parse; data moves only
through a named arm, whose name is bound for the rest of the turn.

The outcome arm on a terminal is NOT settled. `say(...) | ok x |>` is
accepted, but `x` binds an empty value — `{{x}}` renders `""` — while an
undeclared arm word on any outcome-bearing verb is refused. Accepting a
construct and giving it no meaning is the silent-mis-render class the
interpreter is meant to refuse; whether it should be refused or given
a meaning the compiler shares is open.

**Why:** the deleted contract blob taught "never append a continuation
arrow *or outcome arm* to say" — right about the arrow. The earlier
version of this belief called the arm "legal and meaningful (binds
emitted text)" on the strength of gate_probe's docstring and a status
line that never showed the binding's contents — the probe that rendered
`{{x}}` showed it empty. Teaching surface that contradicts the language doesn't just fail to
help — it trains the model to avoid a legal shape while still committing
the illegal one, because the real rule was never stated precisely.

**Open questions:** should an arm on a void tor refuse (like any
undeclared arm word) — and what does koruc say about the same shape?
Did void-say ever bind its text, or did the docstring describe a binder
that skipped void values (koru `bridge.bind.kz` has an uncommitted
change making void values skip `rN`)? Do other
emit-only verbs exist beyond say/note, and is "terminal" a declared
property or an emergent one of void returns?
