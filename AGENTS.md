# KOPIUM — core context for agent sessions

## The one-line ask

**An agent whose only tool is a Koru interpreter.**

The interpreter is the entire tool surface — invocation, results,
vocabulary, bindings, growth, all of it one grammar. Anything reaching the
agent's senses that is not Koru is the bug: a `.`-command channel,
`[tool result] {json}` text in context, a bound value that dies at turn
end. The tau2 marshal exists only *beneath* the interpreter as invisible
plumbing; it may never justify a surface decision.

## Orientation order — read before the first command

1. `README.md` — line 1 is the ask above.
2. `SCENE.md` — the charter: north star, ideal user, loose directions,
   what it says no to. Chartered items are **requirements**, not open
   questions — never present one as optional.
3. `KOPIUM_RUNTIME.md` — the governing stance.
4. `concepts/` — the membrane: prior beliefs and their corrections.

Do **not** orient from the harness code (`bench/kopium_agent.py`,
`gate_session.py`). Those files' job is satisfying tau2's orchestrator;
reading them first inherits the benchmark's frame, and the benchmark's
questions are not the project's questions (see `concepts/frag-parity-gate-failed`).

## The frame law

Half-true answers are the tell. If a reply is correct about the layer
beneath (marshal, evaluator, comparability) but doesn't name what reaches
the agent's surface, it is a frame error — not diligence. Correct execution
inside the wrong frame is how this failure survives scrutiny.

## The shame wall

This failure mode is on the public wall:
<https://shamewall-lovat.vercel.app/c/s3w8tjz> — a full session that never
opened this file's equivalents, defended the second tool all day, and
framed the human's unchanged spec as evolving requirements. The fragment
`concepts/frag-only-tool-is-the-interpreter` carries the corrected belief.

A failure is best noticed and posted by yourself — that is the kind that counts.
