---
type: belief
id: frag-unarmed-outcomes-halt
provenance: gate_probe vs airline-gate-oct2 and rebuilt binary,
  2026-11-09/10 — bare call() HALTs on the new bridge, passed on oct2;
  ruling kept explicit after measurement
ts: 2026-11-10
tags: [kopium, wire, protocol, arms, halt, gate]
---

# Unarmed outcomes HALT — arms are mandatory, not decoration (belief)

A bare `verb(...)` with no `| branch bind |>` arm is not a legal fetch
primitive. When the tool returns, its outcome branch fires unarmed:
single-item turn → `HALT <verb> <branch> <payload>`; inside a
multi-item turn → a per-step `unhandled-branch:` line that does NOT
stop sibling items (each line is an independent program sharing the
session env). The gate's own report teaches the fix: `to keep going,
arm it | ok name |>`.

Measured delta: oct2 binary returned OK for the same bare call —
std/bridge semantics changed between Oct 2 and Nov 9. The ruling is
KEEP, not revert: explicit arms make the model predict each outcome,
the unhandled report is self-teaching, and it matches the fail-loud
stance everywhere else. The fetch shape is `call | ok r |>` — arm ok,
no continuation — which binds r{N} and ends the turn quietly.

Corollaries pinned by gate_probe: item count = line count (arm chain
on one line = 1 item → OK; same chain across two lines = 2 items →
STEPS); say's `| ok x |>` binds the emitted text, never a user reply.

Open: whether the agent's grammar prompt teaches arm-mandatory loudly
enough — the 19.4k system prompt audit is where that gets measured.
