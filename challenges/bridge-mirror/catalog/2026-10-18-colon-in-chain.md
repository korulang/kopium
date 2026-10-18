# 2026-10-18-colon-in-chain — `verb: prose` colon form silently drops in chain-step position

Construct: **the colon form `say: <prose>` as a step after `|>`** — not at a
reply line's head.

Measured this session (kopium `main`, headless probe `probe_colon.k`, notes
scope with `say { text: Source }`):

| position | wire | outcome |
|---|---|---|
| reply line — `say: hello colon world` | admitted: prints `hello colon world`, branch `result` | supported |
| chain step — `read(...) \| ok t \|> say: plain colon no braces` | **silently absent**: the read fires, no say output, no rejection, no residue — branch `result` | **gap** |
| chain step — `read(...) \| ok t \|> say: the file held {{ t }}` | identical silence — the `{{ }}` never gets a chance | **gap** |
| chain step, paren — `read(...) \| ok t \|> say(text: "…{{ t }}…")` | prints interpolated prose | supported |

## Dispositions

- The colon form is a reply-item rule: `wirescan` admits `verb:` only at a
  line's head (runtime.wirescan.kz ~line 76). In chain-step position after
  `|>`, the program parser sees `say: plain colon no braces` and resolves it
  without dispatching `say` and without striking any rejection class — the
  turn reads `result` as if the step succeeded. The plausible reading: `say`
  parsed as a zero-arg invocation, `: <word>` consumed as a return binding,
  the rest dropped. Whatever the mechanism, a spelled verb that never
  dispatches and never refuses is the worst cell on the board — worse than
  `PARSE001`, because nothing in the turn report says the signoff was lost.
- The agent never needs this spelling if the seed teaches paren form in
  chain position — which it now does (`| ok b |> say(text: "…{{ b.field }}…")`).
  But a model that generalizes `say:` from reply position into a chain will
  silently lose its signoff, mid-task, invisibly.
- Float to the compiler session: either admit colon form in step position
  (normalize like the item-head rule) or refuse it loudly (`verb: prose` is
  only admitted at the start of a reply line) — the silent swallow is not a
  third option.

Would correct this row: the step dispatches `say` with the prose, or the
turn rejects the colon spelling with a named refusal.
