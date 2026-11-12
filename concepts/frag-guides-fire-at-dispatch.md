---
type: belief
id: frag-guides-fire-at-dispatch
provenance: R4 commission (doctrine layer v1), built and verified
  2026-11-12 — koru 8c148bdda + this commit; evidence in
  bench/STATUS-R4.md and bench/guides-replay.py
ts: 2026-11-12
tags: [kopium, guides, context-assembly, dispatch, fired_guides]
---

# A guide fires at the dispatch that resolves its key, and one lookup feeds
# both the model and the log (belief)

Doctrine disclosure belongs at the **dispatch record**, not in a prompt
assembler. The interpreter already emits one `TraceEntry` per call with the
verb, the branch word, and the failure flag; that record is the only place
where "this happened" is a fact rather than a reconstruction. So:

- **Key space is `tor->branch` or bare `tor`.** The edge row says what the
  resolved outcome means and where it goes; the tor row says what the verb
  takes and returns (field truth). Edge first, then tor-level — at most two
  rows per dispatch.
- **One lookup, two consumers.** The same call that stamps `fired_guides`
  into the `call_step` record renders the line into the item's report
  (`result.trace`, `RunError.trace`, `unhandled-branch.guides`, or the
  multi-item step report). Log and prompt cannot disagree because there is no
  second derivation.
- **Once per TABLE key per session.** Graduation is per session, never per
  corpus — the model starts blank every run. A wildcard row attributes to
  itself, so a `*->error` lesson is attributable across verbs.
- **Content is domain-general only.** Field names from the generated schema
  and mined payloads, workflow exemplars from train-30 verb sequences with
  slots, judgment frames from the policy document. A guide that only helps
  one task is a failed guide; task ids never appear.
- **Silence is the default.** No table, no matching row, or an already-fired
  key renders nothing; the wire gate still owns legality. Guides are the
  heuristic periphery, not enforcement.

The seam choice matters more than the content. A separate event stream or
Python-side assembly was available and rejected: the gate is the authority
that refused or resolved the call, so the teaching rides its own report, and
`tau-agent.k` already observes that text verbatim. Weakening that (a drain a
harness could forget) would make "what the model saw" a claim about a second
code path.

## Why this is the right depth now

The measured model failures are semantic — hallucinated payload fields,
omitted required args, policy-blind plans — and every one of them is legible
from the dispatch outcome. A static 19k prompt is unconditional; the dispatch
report is the position where the model has just learned the shape of the
world. That is the cheapest possible context assembly: no model, no scorer,
no retrieval index — a compiled table and a file read.

## Open questions (declared, not hidden)

- **Semantic lift is unmeasured.** The rails are proven deterministic
  (fires, injects, records). Whether the model reads better is a spend
  experiment, not a claim this belief can make.
- **The once-per-session cap is empirical.** It prevents flooding, but a run
  that needs the same lesson twice gets it once. The cutoff wants a replay
  measurement, not a taste call.
- **Template language is thin.** The `add` source block is claimed by the
  flow parser (`|>`) and by apostrophes, and the transform collapses
  newlines, so templates are single-line sentences. Richer delivery (file
  embeds, raw regions) is not wired.
- **Table identity is not yet stamped into run provenance.** A run_start
  guide-table hash is the missing attribution link across regenerations.
- **Live-binding exemplars (Phase B) are specified, not built.** Splice
  binding names from the session env (name + field only, never values) so a
  template says `reservation_id: r1.reservation_id`; the gate still judges
  every spliced value.
