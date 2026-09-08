---
type: belief
id: frag-partial-programs
provenance: Lars ruling 2026-09-07, live-define/vulcan-forcing walk — SUPERSEDED IN PART
ts: 2026-09-07
---

# Partial programs are the product; anything that forbids composition is the banned shape

KOPIUM is a system to RUN partial programs. The agent's composition —
several invocations in one turn, chained through handles the interpreter
just issued — is the load-bearing capability, not a luxury. Any prompt text,
wire rule, or grammar shape that talks the model out of composing (the
one-invocation-per-turn law, vocabulary prose that presents the verbs as
fixed and complete, goals that script single calls) makes the whole thing
useless: it refuses actual access to the interpreter while burning a full
reasoning pass per turn.

CORRECTION 2026-09-07, same night: the unhandled-branch half of this belief
was already ruled — by Lars, 2026-08-07, in koru pin 430_056
(`tests/regression/400_RUNTIME_FEATURES/430_RUNTIME/430_056_partially_handled_interpreted_flow/input.kz`):
`run` gains `| unhandled-branch { branch, payload, handles }`; leniency is a
MODE on run; strict refuses pre-flight; payload carries NAMED handles; a
model over a bridge gets the unhandled branch fed back as a message that
teaches it; KORU022 makes the host handle it. The koru-ub worktree
(rb-unhandled-branch) carries the in-flight core (`unhandled_outcome` in
interpreter context). This fragment does not originate that design — it
points at it. What this fragment still owns: the prompt-side ban (no
over-prompting, composition legal) and the wire-sequencing demand below.

# Partial programs are the product; anything that forbids composition is the banned shape

KOPIUM is a system to RUN partial programs. The agent's composition —
several invocations in one turn, chained through handles the interpreter
just issued — is the load-bearing capability, not a luxury. Any prompt text,
wire rule, or grammar shape that talks the model out of composing (the
one-invocation-per-turn law, vocabulary prose that presents the verbs as
fixed and complete, goals that script single calls) makes the whole thing
useless: it refuses actual access to the interpreter while burning a full
reasoning pass per turn.

Over-prompting is the failure mode with a fixed direction: every line of
system prompt that constrains HOW the model may act must justify itself
against the turn-cost it imposes. The disclosure principle governs —
progressive disclosure by the tools themselves, minimal seed, never a
longer system prompt. A rule that costs turns is guilty until measured
innocent (multi-invocation experiment vs the one-line law).

What would correct this: a measured replay where multi-invocation turns
produce mush, refusal churn, or worse cost-per-task than single-invocation
turns under identical goals. Until that measurement exists, composition
stays legal and the prompt stays minimal.

IMPLEMENTED 2026-09-08 — the hand-back fires live, and the vocab-shaped
consequence is now measured:

- `notes read` returns `| ok | missing path` — the scope's first named-branch
  verb. `probe_unhandled_read.k` pins all four shapes through the same
  `std/bridge:run` (lenient) that `live.k` calls: a bare read of an absent
  path hands back `UNHANDLED branch=[missing]` (A), a partial fragment that
  handles only `| ok` hands back when `missing` fires (B), a bare read of an
  EXISTING file also hands back `UNHANDLED branch=[ok]` (C — a named branch
  nobody handled is unhandled even on success), and a handled `| ok` completes
  as `result` (D).
- Live witness: turn 5 of the 8-turn scenario (`read(path: "field-journal.txt")`)
  fired the hand-back; turn 6 the model explained the semantics back — "my
  fragment had no arm for missing, so it went unhandled and the session still
  holds nothing open" — then continued. The teaching message works.
- DESIGN CONSEQUENCE (the belief this section owns): under the one-invocation
  law (clean truncates to one line), a bare call to a branch-returning verb
  ALWAYS hands back — success (`ok`) included — so such verbs are inherently
  two-turn in the live flow unless the fragment handles the outcome. Design
  notes vocabulary knowing a named-branch verb's happy path also returns to
  the host. The alternative — teach the model the arm shape, or let `clean`
  preserve continuation arms — is an open knob, not yet ruled.

What would correct this: `clean` starts preserving continuation arms (making
handled reads single-turn), or a ruling that bare `ok` should complete by
convention — either flips the two-turn consequence while the probes stay the
record of the current semantics.
