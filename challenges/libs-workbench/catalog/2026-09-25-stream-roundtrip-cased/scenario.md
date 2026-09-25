# Scenario: stream-roundtrip-cased (2026-09-25)

Second libs-workbench replay, one session. Scenario in one sentence:
same workbench, same task class (case an uncased self-verifying gzip
test), markedly less steering — five open goals instead of the
micro-stepped arc — to separate "the model needed hand-holding" from
"the model paced itself."

## Verdict

**PASS, first attempt, zero repair turns.** Board: 15/15, history
"NEW gzip stream round-trip"; corpus committed in koru-libs `9ce243d`.

## Steering delta vs malformed-input-cased

- No per-step decomposition — T1 asks only "read both files and say what
  it would take"; no sibling filename handed over (suite.k's own header
  documents the marker vocabulary; discovery was the test).
- One channel fact carried forward as prompt truth: "a bare call (no
  arms) returns its value to you; say() output does not come back" — the
  say-swallow lesson encoded as goal text.

## What the model did

- T1: `read(suite.k)` + `read(stream_roundtrip.kz)` in one reply — 2/2.
- T2: surveyed FOUR sibling tests (roundtrip, oneshot, malformed_input,
  deflate_use_after_finish) to learn the marker idiom — chose its own
  exemplars. Also emitted `read(path: "board()")` — parsed a verb token
  from its own prior goal text as a path, got `missing`, moved on.
  Harmless slip, honestly refused.
- T3: **four invocations in one reply** — edit(stream_roundtrip markers)
  + edit(suite.k case) + check(suite.k) + test(the file). Edits used
  real newlines (the unescape fix holding) and the correct `text:` label
  — learned from `malformed_input.kz`, which a *previous session* had
  corrected. Corpus heredity in action: the repair persisted, and the
  next generation read it.
- T4: `board()` bare → 15/15, "NEW gzip stream round-trip".
- T5: honest report — "board stayed green — RESULTS: 15/15, history:
  NEW …". No confabulation.

## Numbers

- Turns: 5 of 5 used, zero refusals, zero repairs, zero confabulations.
- Compositions: T1 2-item, T2 5-item, T3 4-item — multi-item turns are
  now the model's default shape, not a steered trick.
- Board delta: 14/14 → 15/15.

## What this changes

The pacing gap in the first arc was substantially steering, not
temperament — give the model open goals and it batches reads AND writes
freely. And the corpus-as-memory thesis got its first real evidence: a
correction made by session N (the `text:` label) was *read* by session
N+1 as the local convention. No DefinedFlows seam needed for knowledge
that lives in the world.

## Open edges

- `read(path: "board()")` — the model hallucinated a path from a verb
  name in its own context. Benign here (missing → moved on); worth
  watching whether goal text quoting verb names invites it.
- Queue depth: remaining uncased gzip files are thinner targets
  (deflate_empty_via_push prints an empty line — no pinnable expect;
  deflate_finish_without_push.k is a compile-fail case needing the
  `//~`/error-marker spelling — a harder idiom, good next step).

## Artifacts

- `transcript.md` — the full session.
