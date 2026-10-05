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
malformed wire; clean partials stay free, and observer residue is free
**once per edge question** — the exemption answers the question asked,
it is not a lane.

The progressive ladder this completes: prose is captured (rung 1, free),
`note` is offered (rung 2, sanctioned), and near the bound the wire asks
"what were you trying to do?" (rung 3, elicitation) — each rung pays for
signal only as failure deepens, and no rung rescues the run.

## Open questions

- The observed "misspellings" were type inference, not bad quoting: models
  treated `text:` as a text-typed position. The wire's value grammar is
  meant to be directed by the declared field type — `name<x>` already does
  this (a minted-handle type admits only minted handles) — so `expr:
  Expression` and `source: Source` are the same declaration shape as
  `var: string`, and each type names its position's wire form: quoted
  literal, raw text to end of line, Koru expression over the session's
  bindings. The flat head-arg validator is bootstrap scaffolding that never
  learned to consult the declared type; the open question is which field
  types drive which wire shapes, not whether "a verb takes trailing text"
  becomes a bespoke grammar rule. Lars's call — the ruling is about the
  type grammar.
- ~~A permanently-free observer lane can theoretically loop forever~~ —
  proven, task28 2026-10-05: 246 exempt observer residues (the model's
  task was done; its malformed notes were all it emitted) until the
  900s watchdog killed the sim. The bound that holds the intent without
  the loop: `bump-fail` clears `observer_answered` when the edge question
  goes out, the first observer residue answers it free, and every later
  one strikes — so a note-loop dies at the rejection bound like any
  other. Probe-pinned in `bench/probe_observer.k`; task 28 replayed to
  reward 1.0 in 18 model calls.
