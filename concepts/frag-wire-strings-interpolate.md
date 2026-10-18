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
quoted-string branch covers every verb and every field type — string,
Source, Expression alike. `{{ name }}` and `{{ name.field }}` inside a wire
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

The measured boundary: colon form `say: prose` is a reply-item rule
(runtime.wirescan.kz) and in chain-step position after `|>` it silently
drops — no dispatch, no rejection, `result` reported (catalog:
bridge-mirror/2026-10-18-colon-in-chain). Paren form in step position is
the honest spelling; until the toolchain rules, `say:` outside item-head
position is a trap.

Supersedes-in-part the stale clause in frag-the-harness-delivers-bound-prose
("Source captures literally — a bare name in that position is text"): bare
names in captured fields resolved already (koru 01c66c452); `{{ }}` now
composes inside the text itself.
