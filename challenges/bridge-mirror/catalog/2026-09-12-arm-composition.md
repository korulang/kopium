# 2026-09-12-arm-composition — nested arms work; piped arm chains refuse; bindings die at the item boundary

Construct: **arm-body composition** — what may live on the right of
`| branch |>`, and whether a bound name outlives its item.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | compiled `.k` | bridge `source:` | class |
|---|---|---|---|
| nested arms (an arm whose body invokes with its own arms) | supported | **supported** — `missing` fired a nested `read`, its `ok` ran `say` | supported |
| piped arm chain `\| ok h \|> a() \|> b()` | supported — arms hold flows | `parse-error` (`MalformedNode` single-item; `No flow found` mid-item) — refused, message opaque | refused-honest |
| ~~binding used by a later item (`open` binds `h` in item 1, `append(handle: h)` in item 2)~~ | ~~supported — a binding flows forward~~ | ~~item 2 ran `append` with literal `"h"` → `dispatch-error: HandleNotHeld`. Environments are per-item; the unbound name passed as a string~~ | ~~gap~~ **closed** |

**Closed 2026-09-16** (koru `15d8745ab`, pin `440_026`). The row closed
at two walls, one law: a bare identifier is a reference, never a
literal. Item 2's `append(handle: h)` dies at the wire parser —
`step 2/2 parse-error: the value of 'handle' must be a double-quoted
string` — because item heads admit no bare values at all. The
identifier's own text can never reach dispatch. And where a bare
identifier *can* parse — an arm body is a Koru fragment — the flow's
validation carries a bound set along each arm path: `h` under `| ok h
|>` resolves; `t` under a sibling `| absent a |>` arm, or `h` in
`h.msg`, is `validation-error` naming the name (`unbound 't' on 'echo'
— bind it with an arm or quote it for a literal`). Per-item scope is
the semantics, and every reference now refuses honestly instead of
stringifying into `HandleNotHeld`.

~~Disposition: two separable fixes. The honest refusal (unbound
identifier → named validation error, not string literal) is
interpreter-side.~~ Both halves landed: the refusal names the binding,
and no ruling on cross-item bindings was needed — the wire's own
grammar refuses the shape before scope is ever the question.
