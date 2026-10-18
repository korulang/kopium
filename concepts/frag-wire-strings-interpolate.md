---
type: belief
id: frag-wire-strings-interpolate
provenance: kopium headless probes 2026-10-18 — probe_say_field.k and
  probe_colon.k, notes scope; and the design ruling that "compose a returned
  value into prose in the same reply" is absolutely key, else the agent is
  structurally forced into a second turn to author a static sentence
ts: 2026-10-18
tags: [kopium, wire, interpolation, say, bridge, grammar]
---

# Wire strings interpolate `{{ name }}` against session bindings (belief)

Every invocation argument flows `evaluateExpr` before dispatch
(`interpreter.run.kz` ~line 784), so one substitution point in the
quoted-string branch covers every verb and every field type — string and
Expression alike. `{{ name }}` and `{{ name.field }}` inside a wire
string splice the bound value's text; a name nobody bound refuses with a
named dispatch-error that teaches `| ok name |>`; `{{` that does not open a
dotted identifier stays literal, so prose may carry braces. fmt's `:s`
habit is accepted and ignored — the wire has no rendering sigils.

This deletes a structurally forced round-trip. Before it, the agent could
emit a bound value bare (`say(text: t)`) or emit static prose — never
compose "Booked {{ b.reservation_id }}" in the reply that dispatched the
call. The armed-signoff pattern — `call | ok b |> say(text: "...{{ b.x }}")` —
is now expressible, and the seed teaches it: the signoff rides the arm,
conditioned on what the dispatch actually did, in one model call.

Same-day correction, second ruling: the wire has ONE spelling —
`verb(field: value)`. The colon form `say: prose` is deleted end to end
(segmenter, scanner, grammar text, teaching); a colon-headed line now
binds as residue and `440_046` pins the refusal. `Source` is purged from
wire scope entirely: it is the language's comptime source-fragment type
(ast.zig — "captured source code"), never a prose field type — `say`,
`note`, `bind` carry plain `string`, and `{{ }}` makes quoting sufficient.
`Expression` remains the bare-capture hook for fields whose value is
expression-shaped (`calc(expr: 2 + 3)`, airline composites `[{...}]`) —
it is the same ast.zig comptime-only family and Lars has not ruled it
clean. The surviving gap is positional: `|> say: x` in a chain step still
silently drops (catalog: bridge-mirror/2026-10-18-colon-in-chain) — the
program parser's bug, not the item scanner's.

Supersedes-in-part the stale clause in frag-the-harness-delivers-bound-prose
("Source captures literally — a bare name in that position is text"): bare
names in captured fields resolved already (koru 01c66c452); `{{ }}` now
composes inside the text itself.
