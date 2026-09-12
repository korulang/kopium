# 2026-09-12-branch-arms — continuation arms: named multi-arm works; `|?` parses and never fires

Construct: **branch-continuation arms** — `verb(...) | branch bind |> next()`,
in three facets: multi-arm named dispatch, the `|?` catch-all, and sibling
arms that bind the same name.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | compiled `.k` | bridge `source:` | class |
|---|---|---|---|
| multi-arm named dispatch (`ok`/`missing`/`too-large`, distinct bindings) | supported | **supported** — `missing` fired, payload bound, `say` ran | supported |
| payload binding into next call (`\| ok text \|> say(text: text)`) | supported | **supported** — the `ok` payload reached `say` | supported |
| catch-all `\|? b \|>` (koru `210_017`, `355_009-011`) | supported | **gap** — parses clean, then does not catch: `missing` hands back `unhandled-branch` as if no arm existed | gap |
| sibling arms binding the same name (`\| missing p \|>` + `\| too-large p \|>`) | supported — arms scope their own bindings | **gap** — `validation-error: Shadowing not allowed: binding already exists`. The refusal mislabels the construct: sibling arms are disjoint scopes, not a shadow | gap |

## Dispositions

- **`|?` never fires** is the sharper seam: the interpreter's own parser
  accepts the arm (no parse-error), then eval never matches it — an arm that
  lies by existing. Wants a koru fix in `interpreter` eval (honor
  `is_catchall`), or — if catch-alls are deliberately out of the wire's
  power — a loud parse-time refusal. Silent is the one wrong answer.
- **sibling same-name bindings** wants the interpreter's environment scoped
  per arm-continuation the way the compiler scopes them, or a message that
  says what is true ("the interpreter binds arm names flow-wide") instead
  of "shadowing".
- Both are koru-side (`koru_std/interpreter*.kz`), not kopium workarounds —
  per the one law, nothing here gets routed around in the app.

## Repro

`read(path: "no-such.txt")\n|? b |> say(text: "caught")` through
`std/bridge:run` → `unhandled-branch missing` (should be `result`).
`read(path: "no-such.txt")\n| missing p |> say(text: "a")\n| too-large p |>
say(text: "b")` → `validation-error: Shadowing not allowed` (compiled
surface: same-name sibling arms compile and run — `| ok c |>` / `| failed
c |>` on `std/io:read-file`, verified).

Would correct this row: either repro changes verdict — the `|?` arm fires,
or the same-name program dispatches. A deliberate-narrowing ruling converts
a `gap` cell to `refused-honest` only when the refusal names the real
reason.
