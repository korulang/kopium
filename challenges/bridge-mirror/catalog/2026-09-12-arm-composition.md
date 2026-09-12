# 2026-09-12-arm-composition — nested arms work; piped arm chains refuse; bindings die at the item boundary

Construct: **arm-body composition** — what may live on the right of
`| branch |>`, and whether a bound name outlives its item.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | compiled `.k` | bridge `source:` | class |
|---|---|---|---|
| nested arms (an arm whose body invokes with its own arms) | supported | **supported** — `missing` fired a nested `read`, its `ok` ran `say` | supported |
| piped arm chain `\| ok h \|> a() \|> b()` | supported — arms hold flows | `parse-error` (`MalformedNode` single-item; `No flow found` mid-item) — refused, message opaque | refused-honest |
| binding used by a later item (`open` binds `h` in item 1, `append(handle: h)` in item 2) | supported — a binding flows forward | item 2 ran `append` with literal `"h"` → `dispatch-error: HandleNotHeld`. Environments are per-item; the unbound name passed as a string | gap |

The narrowing itself is defensible — items are separate flows, and the
wire's binding story is `| ok h |>` inside one item — but the failure mode
lies: an unbound identifier should fail "no such binding," not dispatch
with the literal text of the name. A model that learned Koru's
flow-forward bindings gets a HandleNotHeld that blames the handle, not
the missing binding.

Disposition: two separable fixes. The honest refusal (unbound identifier
→ named validation error, not string literal) is interpreter-side. Whether
bindings *should* cross items is a wire-semantics ruling — if they should,
that is a bigger change to sequencing (shared env across `run_event`
calls) and deserves its own walk.

Would correct this row: item 2's `append(handle: h)` reports
`step N/M validation-error` naming the unbound binding — or `h` resolves
if cross-item bindings are ruled in.
