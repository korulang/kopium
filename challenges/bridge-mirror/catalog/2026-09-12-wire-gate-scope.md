# 2026-09-12-wire-gate-scope — the wire gate was single-item only; now holds per item (koru b1952ac18)

Construct: **the wire shape rules** — `verb(field: "value")`, quoted-string
values, one invocation per item — as enforced (or not) per turn shape.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| facet | single-item turn | item inside a multi-item turn | class |
|---|---|---|---|
| bare (unquoted) field value `say(count: 3)` | `parse-error`: "must be a double-quoted string" | `step N/M parse-error` with the same wire message — koru `b1952ac18`, pinned by `440_021` | refused-honest |
| bare identifier arg `append(handle: h, ...)` | wire-refused | `step N/M parse-error` — the same gate, per item | refused-honest |
| trailing text / `when` clause `say(...) when true` | `parse-error`: "nothing follows the closing ')' except arms" | `step N/M parse-error` — the same gate, per item | refused-honest |

The seam WAS: `koru_std/bridge.run.kz` applied `parse_wire_event` inside
the `items.len < 2` branch only, and multi-item slices went straight to
`run_event.handler`. Fixed koru-side in `b1952ac18`: `wireGate` in the new
`bridge.turn.kz` part is the single predicate both paths share — every
item is gated before dispatch, and a refused slice is a step line, never
a silent run.

A model that learns "bare values are refused" from one reply can emit them
freely in a two-step turn — and an unquoted `h` that should fail "not a
string" silently becomes the literal `"h"` and dies downstream as
HandleNotHeld. Knowledge transfers badly in exactly this direction: the
refusal a single turn teaches does not generalize to the turn shape the
wire flip introduced.

Disposition: RESOLVED koru `b1952ac18` — `parse_wire_event` runs per item
inside the sequencing loop via the shared `wireGate` predicate (narrowing
kept honest — the wire is one grammar, judged per item).

The map's correction criterion is met: a mid-turn bare value or prose
line reports `step N/M parse-error` with the wire's own message, and the
turn runs on.
