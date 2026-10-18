# 2026-10-18-colon-in-chain — `verb: prose` colon form silently drops in chain-step position

Construct: **the colon form `say: <prose>` as a step after `|>`** — not at a
reply line's head.

Measured this session (kopium `main`, headless probe `probe_colon.k`, notes
scope with `say { text: string }` after the same-day colon-form deletion):

| position | wire | outcome |
|---|---|---|
| reply line — `say: hello colon world` | **residue** (was: admitted) — the colon form is gone; `440_046` pins the refusal | refused loudly |
| chain step — `read(...) \| ok t \|> say: plain colon no braces` | **silently absent**: the read fires, no say output, no rejection, no residue — branch `result` | **gap** |
| chain step — `read(...) \| ok t \|> say: the file held {{ t }}` | identical silence — the `{{ }}` never gets a chance | **gap** |
| chain step, paren — `read(...) \| ok t \|> say(text: "…{{ t }}…")` | prints interpolated prose | supported |

## Dispositions

- Same-day status change: the colon form is **deleted** — `verb:` prose is
  residue at reply level now (`440_046` pins it), so a model cannot learn
  the spelling from the grammar at all. What remains is the step-position
  half of the bug: `|> say: x` still parses silently — the program parser
  reads it as a zero-arg invocation with a `: x` bind and drops the rest.
  The gap narrowed (nobody's taught the spelling anymore) but the swallow
  is still real: a model that reinvents `verb:` inside a chain loses its
  step invisibly.
- Float to the compiler session: `verb: <anything>` after `|>` must refuse
  loudly — `:` in step position should be a named parse-error, not a
  silent bind-and-drop. (The reply-level admission it depended on is gone;
  there is no colon spelling to admit at any position.)

Would correct this row: the step refuses `say: x` with a named refusal.
