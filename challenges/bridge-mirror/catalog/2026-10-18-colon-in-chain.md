# 2026-10-18-colon-in-chain — `verb: prose` colon form silently drops in chain-step position

Construct: **the colon form `say: <prose>` as a step after `|>`** — not at a
reply line's head.

Measured this session (kopium `main`, headless probe `probe_colon.k`, notes
scope with `say { text: string }` after the same-day colon-form deletion):

| position | wire | outcome |
|---|---|---|
| reply line — `say: hello colon world` | **residue** (was: admitted) — the colon form is gone; `440_046` pins the refusal | refused loudly |
| chain step — `read(...) \| ok t \|> say: plain colon no braces` | **silently absent** at measure time — now **`refused: MalformedNode`** (`440_048`) | fixed |
| chain step — `read(...) \| ok t \|> say: the file held {{ t }}` | identical silence — now `MalformedNode` | fixed |
| chain step, paren — `read(...) \| ok t \|> say(text: "…{{ t }}…")` | prints interpolated prose | supported |

## Dispositions — resolved same day

- The colon form is **deleted** — `verb:` prose is residue at reply level
  (`440_046` pins it), so a model cannot learn the spelling at all.
- The step-position half is **fixed**: `flow_parser`'s `parseNode` took
  `say: the prose` down its "branch constructor with plain value" path —
  a loose first-char check let `say:` ride in as a branch name, so the
  step became a label and never dispatched. The guard now requires a
  plain branch name, `say:` fails it, and the step dies as a named
  parse-error (`MalformedNode`) the model can see. Pinned red by
  `440_048_colon_in_chain_step_is_refused`: the same wire also proves the
  canonical `|> say(text: "...{{ t }}")` step still dispatches.

This row is corrected: the step refuses `say: x` with a named refusal.
