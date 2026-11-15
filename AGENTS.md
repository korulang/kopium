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

## Measurement discipline — receipt first, always

A benchmark reward is a lagging indicator, never the oracle. The oracle is
the request body (`bench/results/runs/*/receipts/call_*.json`) — what the
model actually saw.

- 0.0 on a repeated shape means READ THE RECEIPTS before running anything
  else. A wall of identical failures is a protocol bug until proven
  otherwise, not a model limitation.
- Never run-and-patch: no rerun to "see if it works" without first naming
  what the request body contained.
- "Model issue" is a hypothesis allowed ONLY after the request body is
  verified clean. Until then it is blame without evidence.
- If the trajectory and the request body disagree, the request body wins —
  the trajectory is downstream of whatever the model was shown.

## Design law — no escape hatches, ever

The surface computes what the agent needs; it never fetches it. Every verb
self-describes from its declaration; affordances render what is callable
now; guides deepen post-dispatch. When the surface is insufficient, fix
the structure — dissolve content into the declarations and the computed
views — never route around it with more surface.

Banned, absolutely:

- Fetch-a-manual verbs (`contract()` — removed `46fc178`; 0 calls in every
  receipt proved it was dead surface). Doctrine the model must know to
  fetch is doctrine it will never fetch.
- Degraded fallback paths labeled as defaults (the global no-fallbacks law
  applies here double).
- Bolt-on doctrine blobs, second channels around the interpreter, or any
  surface added because "the model keeps getting it wrong" — if the model
  keeps failing a shape, the shape or the computed view is wrong, not the
  model's work ethic.
- Doing it "of your own volition" when the design contradicts the thesis.
  Surface additions are Lars's call, always.

An escape hatch counter to the thesis is worse than a missing feature: it
teaches the agent — and the next session — that the real path doesn't have
to work.

## The shame wall

This failure mode is on the public wall:
<https://shamewall-lovat.vercel.app/c/s3w8tjz> — a full session that never
opened this file's equivalents, defended the second tool all day, and
framed the human's unchanged spec as evolving requirements. The fragment
`concepts/frag-only-tool-is-the-interpreter` carries the corrected belief.

A failure is best noticed and posted by yourself — that is the kind that counts.
