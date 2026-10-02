---
type: belief
id: frag-the-observer-channel
provenance: kopium bench smoke 2026-09-30 — three airline tasks died at the
  rejection bound while narrating full reasoning as residue; the same runs
  went 4/5 reward-1.0 once the narration had a sanctioned lane
ts: 2026-09-30
tags: [kopium, bridge, observer, wire, residue, introspection]
---

# The observer channel: reasoning is a third lane, not a second tool (belief)

A model driving a Koru wire leaks its reasoning as prose no matter what the
prompt says — that is the trained prior, and punishing it teaches hiding,
not grammar. The wire therefore has three lanes, not two: `say`/scope verbs
act on the world, prose binds as residue, and `note(text:)` — granted only
by `introspection: true` beside `vocabulary`/`grammar`/`bind` — is the
sanctioned lane where thinking out loud is free, captured in the wire
source, and acknowledged with a bare `ok` (never echoed, never sent to the
user, never in the scope dispatcher).

The ruling the smoke earned: **meet the misspelling, don't punish the
intent.** Every observed note attempt used bare prose — `note(text: I see
my mistake)`, `note: <prose>` — so an introspection session classifies a
failed `note(`/`note:` item as observer residue, and a `note(...)` glued
to a same-line call splits at the first `)` whose suffix passes the gate
(the malformed note was swallowing live calls into its residue string).
`partial` counts `wire_failures` so the rejection bound still kills
malformed wire; observer residue and clean partials stay free.

The progressive ladder this completes: prose is captured (rung 1, free),
`note` is offered (rung 2, sanctioned), and near the bound the wire asks
"what were you trying to do?" (rung 3, elicitation) — each rung pays for
signal only as failure deepens, and no rung rescues the run.

## Open questions

- Models keep voting for a raw-text note form the grammar does not have
  (`note:` trailing text to end of line). Whether "a verb takes trailing
  text" becomes a wire-grammar shape is Lars's syntax call — the runtime
  carve is the bridge, not the answer.
- A permanently-free observer lane can theoretically loop forever (the
  strike bound never engages on pure-note turns); unproven whether that
  needs its own bound once raw-text lands.
