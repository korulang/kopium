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
failed `note(`/`note:`-headed item as observer residue, and a `note(...)` glued
to a same-line call splits at the first `)` whose suffix passes the gate
(the malformed note was swallowing live calls into its residue string).
(2026-10-18: both cited spellings are now refused — `note:` is gone with
the colon form and `note`'s `text` is a plain `string`, so bare prose
parses as a bound name and fails; the `note(`/`note:` head detection
still routes the *intent* to observer residue, which is what this rung
is for — the teaching message now names only `note(text: "...")`.)
`partial` counts `wire_failures` so the rejection bound still kills
malformed wire; clean partials stay free, and observer residue is free
**once per edge question** — the exemption answers the question asked,
it is not a lane.

The progressive ladder this completes: prose is captured (rung 1, free),
`note` is offered (rung 2, sanctioned), and near the bound the wire asks
"what were you trying to do?" (rung 3, elicitation) — each rung pays for
signal only as failure deepens, and no rung rescues the run.

## Open questions

- ~~The observed "misspellings" were type inference~~ — **ruled
  2026-10-18**: `Source` was never a prose type; it is the language's
  comptime source-fragment type (`ast.zig`, "captured source code"), and
  declaring prose fields `Source` was the bastardization. The purge:
  `say`/`note`/`bind` carry `string`; only `Expression` fields keep
  bare-text admission (`calc(expr: 2 + 3)`, airline composites `[{...}]`),
  and its survival is itself unruled — same comptime-only family
  (`ast.zig:488`). `name<x>` possession typing stays as the real
  type-directed admission.
- ~~A permanently-free observer lane can theoretically loop forever~~ —
  proven twice, and the second proof is the sharper one. Task 28
  (2026-10-05): 246 *malformed* observer residues — exempt from the
  rejection bound — until the 900s watchdog. The fix: `bump-fail` clears
  `observer_answered` when the edge question goes out, the first observer
  residue answers it free, every later one strikes. Task 46 (2026-10-06):
  ~200 *well-formed* `note(...)` calls — each parsed, ran, returned `ok`,
  delivered nothing — while the model waited for a request it judged
  absent. The rejection bound counts failures; this loop was all
  successes, so the liveness question is not "did the wire parse" but
  "did the reply reach anyone": `mark-call-start` snapshots
  `n_say + n_call`, `delivered` reads the delta, and six consecutive
  silent replies die at the same edge/over bound as refusals — a
  separate streak, so silent turns don't conflate with rejected ones.
  Effect, not validity, is what a bound may exempt. Both instances
  probe-pinned in `bench/probe_observer.k`; task 28 replayed to reward
  1.0 in 18 calls, task 46 to 1.0 in 5.
