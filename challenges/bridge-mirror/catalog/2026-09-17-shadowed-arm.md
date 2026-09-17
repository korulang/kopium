# 2026-09-17-shadowed-arm — a second unguarded same-branch arm is dead text; the wire now refuses it

Construct: **shadowed sibling arms** — `a | ok h |> b | ok h2 |> c`, where the
writer means a chain and the grammar reads siblings of the head call.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`,
probe `headless/probe_discharged.k`; koru `a01abb341`):

| facet | compiled `.k` | bridge `source:` | class |
|---|---|---|---|
| second unguarded arm on a branch an earlier sibling answers | `SHAPE002` refused at compile (`branch_checker.firstDuplicateSibling`) | was `result` — the arm never fired and nothing said so — the "discharged-handle" defect: `close` sat in dead text, the pool kept the handle, the next turn's append re-used it (`alpha\nalpha`) | ~~gap~~ **closed** |
| guarded arm + unguarded same-branch fallback | legal — `when` narrows | legal — guarded priors don't shadow (`440_024` shape stands) | supported |
| arm indented under a step's line | nested arm on the step | nested arm on the step — the chain spelling the refusal teaches | supported |
| flat arms naming distinct branches | siblings, both reachable | siblings, both reachable — the legal use of the flat shape | supported |

**Closed this session** (koru `a01abb341`, pin `440_027`). The interpreter's
`validateFlow` gained `checkShadowedArms` — the mirror of
`firstDuplicateSibling`: an unguarded terminal arm shadowed by an earlier
unguarded same-name sibling is `validation-error`, and the message teaches
the nesting spelling ("indent the arm under the step it follows"). Flat
`open | ok h |> append | ok h2 |> close(h2)` now refuses instead of
reporting `result` with the close never dispatched; the indented form runs
and leaves `handles=0`. Same judge on both surfaces — `when` narrows, `|?`
falls back, `!` composes.

Side catch: koru's own `410_002` had the dead-arm shape in its source —
`expensive | processed |> expensive | processed |> result` — masked because
budget exhaustion fired before the shadowed arm mattered. The pin still
holds; the source now spells the chain nested.
