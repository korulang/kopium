# 2026-09-12-when-guards — `when` parsed mid-turn and ran mangled; now wire-refused per item (koru b1952ac18)

Construct: **`when` guards on invocations** — `verb(...) when <expr>`,
conditional dispatch the compiler honors and `flow_parser` knows.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| surface | `say(text: "b") when false` | class |
|---|---|---|
| compiled `.k` | supported — guard evaluated, call skipped | — |
| single-item bridge source | `parse-error`: "one flow per turn: nothing follows the closing ')' except arms" — refused-honest | refused-honest |
| item inside a multi-item turn | `step N/M parse-error` — "nothing follows the closing ')' except arms"; koru `b1952ac18`, pinned by `440_021` | refused-honest |

The mid-turn verdict WAS the worst cell in the map: accepted, reported
`result`, verb fired with a mangled argument. Fixed koru-side in
`b1952ac18` — the per-item wire gate refuses `when` on invocations the
same way a single-item turn does.

Note the boundary of this fix: it covers `when` on the invocation
(`verb(...) when x`). A `when` inside an arm (`| ok h when <expr> |>`)
is a different cell — `flow_parser` stores it as `cont.condition` and the
interpreter never evaluates it — still a gap if the wire lets it through.

Disposition: RESOLVED for the invocation-level construct. Arm-level
guards want the same ruling applied at eval: honor `cont.condition` or
refuse it, never run it ungated — a candidate next map row.
