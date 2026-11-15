---
type: belief
id: frag-emit-only-terminal-pipes
ts: 2026-11-15
tags: [kopium, wire, semantics, probes, say, note]
provenance: TauGateSession probes 2026-11-15 closing matrix cell #4 —
  say/note pipe behavior verified after contract text taught it wrong;
  evolved same day by bench/probe_pipe_semantics.py (cells #5, #6) and
  Lars's ruling that `|>` after a void tor is the language's backbone
---

# frag-emit-only-terminal-pipes

**Belief:** `say` and `note` are void tors — no return value, no outcome.
A bare `|>` after any void tor sequences the next call; that is the
backbone of Koru, and the wire speaks it exactly as compiled Koru does.
A trailing `|>` with nothing after it is a partial program and runs.
An outcome arm on a void tor (`| ok x |>`, `| ok |>`, `| ok _ |>`) is a
shape bug and refuses — there is no outcome to listen to. `|>` never
carries data on its own: data moves only through a named arm on a tor
that declares that outcome, and after an outcome-bearing tor a bare
`|>` names no outcome, so the result is handed back unhandled.

**Why:** this belief was wrong twice in one day, both times by trusting
the bridge as if it were the language. First, "terminals cannot emit
`|>`" — the probe was real, but it measured a bridge parser that only
split continuations at `| word` heads, not the language; every compiled
harness chains void steps with a bare `|>`. Second, "the arm on say is
legal and binds the emitted text" — read off a docstring and a status
line that never showed the binding; it bound nothing, and a void tor has
nothing to bind. The bridge is evidence about the bridge. What the
language says comes from the declaration and the compiler.

**Open questions:** does koruc itself refuse a bare `|>` after an
outcome-bearing tor, or accept it as an unhandled path — i.e. is the
bridge's hand-back a deferral or a divergence? Is "void" worth naming
in the rendered vocabulary so the model sees it before dispatch?
