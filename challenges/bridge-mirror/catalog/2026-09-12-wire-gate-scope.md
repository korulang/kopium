# 2026-09-12-wire-gate-scope — the wire gate is single-item only; mid-turn items skip it

Construct: **the wire shape rules** — `verb(field: "value")`, quoted-string
values, one invocation per item — as enforced (or not) per turn shape.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | single-item turn | item inside a multi-item turn | class |
|---|---|---|---|
| bare (unquoted) field value `say(count: 3)` | `parse-error`: "must be a double-quoted string" | **ran** — `step 2/2 result`, no refusal | gap |
| bare identifier arg `append(handle: h, ...)` | wire-refused | dispatched literally — `HandleNotHeld` on `"h"` | gap |
| trailing text / `when` clause `say(...) when true` | `parse-error`: "nothing follows the closing ')' except arms" | **ran** — `step result`, guard not gated | gap |

The seam: `koru_std/bridge.run.kz` applies `parse_wire_event` inside the
`items.len < 2` branch only. Multi-item slices go straight to
`run_event.handler` — the comment claims "every slice still passes the
single paths' validators," which is not true of the *wire* validator: the
shape rules (quoted values, invocation-only) are skipped per item. What
still holds is whatever `run_event` enforces internally (scope membership,
dispatch) — the strict agent-facing grammar is single-turn only.

A model that learns "bare values are refused" from one reply can emit them
freely in a two-step turn — and an unquoted `h` that should fail "not a
string" silently becomes the literal `"h"` and dies downstream as
HandleNotHeld. Knowledge transfers badly in exactly this direction: the
refusal a single turn teaches does not generalize to the turn shape the
wire flip introduced.

Disposition: either `parse_wire_event` runs per item inside the
sequencing loop (narrowing kept honest — the wire is one grammar, not
two), or the comment stops claiming it. The loop-site validation is the
koru-side fix; nothing in kopium should compensate.

Would correct this row: a mid-turn bare value or prose line reports
`step N/M parse-error` with the wire's own message.
