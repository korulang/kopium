# 2026-09-12-branch-arms — continuation arms: named multi-arm works; `|?` now fires (koru b1952ac18)

Construct: **branch-continuation arms** — `verb(...) | branch bind |> next()`,
in three facets: multi-arm named dispatch, the `|?` catch-all, and sibling
arms that bind the same name.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | compiled `.k` | bridge `source:` | class |
|---|---|---|---|
| multi-arm named dispatch (`ok`/`missing`/`too-large`, distinct bindings) | supported | **supported** — `missing` fired, payload bound, `say` ran | supported |
| payload binding into next call (`\| ok text \|> say(text: text)`) | supported | **supported** — the `ok` payload reached `say` | supported |
| catch-all `\|? b \|>` (koru `210_017`, `355_009-011`) | supported | **supported** — was a gap (parsed, never fired); koru `b1952ac18` honors `is_catchall`: the arm fires as fallback and binds the outcome, pinned by `440_020` | supported |
| metatype catch-all `\|? M b \|>` | supported — filters on outcome metatype | **refused-honest** — interpreter outcomes carry no metatype; when `|? M b` is the only fallback, dispatch refuses `CatchallMetatypeUnsupported` rather than catching what compiled code would not | refused-honest |
| sibling arms binding the same name (`\| missing p \|>` + `\| too-large p \|>`) | supported — arms scope their own bindings | **gap** — `validation-error: Shadowing not allowed: binding already exists`. The refusal mislabels the construct: sibling arms are disjoint scopes, not a shadow | gap |

## Dispositions

- **`|?` never fires** — RESOLVED koru `b1952ac18`. The interpreter's own
  parser accepted the arm, then eval never matched it — an arm that lied
  by existing. Arm selection moved to `interpreter.select.kz`: the bare
  catch-all fires as fallback and binds the outcome; the metatype form
  refuses loudly because the filter cannot be evaluated.
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

Would correct this row: either repro changes verdict — the `|?` arm fires
(done, `b1952ac18`), or the same-name program dispatches. A
deliberate-narrowing ruling converts a `gap` cell to `refused-honest` only
when the refusal names the real reason (the metatype catch-all now does).
