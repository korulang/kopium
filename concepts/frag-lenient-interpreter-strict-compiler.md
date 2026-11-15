---
type: belief
id: frag-lenient-interpreter-strict-compiler
ts: 2026-11-15
tags: [kopium, koru, interpreter, compiler, bridge-mirror, semantics]
provenance: Lars 2026-11-15 — "the interpreter should be lenient, the
  compiler strict, both reflecting the same language as far as the
  subset allows"; worked through cells 3–6, 22, 23 of
  bench/WIRE-GAP-ANALYSIS.md and the bridge-mirror `deferred` class
---

# frag-lenient-interpreter-strict-compiler

**Belief:** one meaning, two times to judge it. The bridge interpreter may
move *when* a compiler verdict lands — run the program and hand the
problem back as a named outcome when the path is reached (unhandled
branch, residue parked as `rN`, a trailing `|>` run as a partial
program). It may never give a construct a meaning the compiler would
give differently, and never refuse a compiler-legal construct with a
message that misnames it. Completeness errors defer; meaning errors
(unknown field, undeclared arm word, arm on a void tor, shadowing)
refuse before dispatch with the compiler's judgment; unimplemented
subset refuses and says so.

**Why:** every lie the bridge-mirror ever caught came from leniency on
meaning — `|?` that never fired, `when` that ran unchecked, an arm on
`say` that bound nothing. And the opposite failure is just as real:
the bridge refused void-tor `|>` chains, sibling arms with one name,
and nested field paths — all plain Koru — and agents were taught those
refusals as the language. The bridge is evidence about the bridge;
the declaration and the compiler say what the language is.

**Open questions:** does koruc accept a bare `|>` after an outcome
tor, making the bridge's hand-back a true deferral? Should the
interpreter share the compiler's checker code rather than mirror it,
so the two judges cannot drift?
