---
type: belief
id: frag-partial-programs
provenance: Lars ruling 2026-09-07, live-define/vulcan-forcing walk
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
