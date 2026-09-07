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
