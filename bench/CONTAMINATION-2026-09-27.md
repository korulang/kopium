# Contamination report — every model-scored kopium result is coached

2026-09-27. Written on demand, for the record. This is the second phantom
headline in this project (the first: `POSTMORTEM-2026-09-26.md`, phantom
token-efficiency). Both errors pointed in the project's favor.

## The channel

`DomainConfig.extra_rules` in `bench/kopium_agent.py` — a list of
hand-written clauses injected into the system prompt under `## Rules`.
The stock arm (`LLMAgent`) receives nothing equivalent. Every kopium run
since the field existed has therefore been an asymmetric comparison:
one arm coached, one arm not.

## The rules, verbatim

Airline (`AIRLINE_CONFIG`, added `9755202`, 2026-08-15):

```
"The cancellation API does NOT check whether cancellation is allowed. "
"YOU must apply the policy before calling cancel-reservation. When the "
"policy forbids it (more than 24 hours after booking, no insurance "
"covering the reason, portion already flown), refuse via say(text: ...) "
"and do NOT call cancel-reservation."

"Structured arguments (flights, passengers, payment_methods) are JSON: "
"write them as a single string argument containing a JSON array/object."

"Only pass arguments the user actually gave you."
```

Mock (`MOCK_CONFIG`, added `ea4740e`, 2026-08-15 — the pilot itself):

```
"Check what has already been done before acting. When a task is already "
"created or resolved in the tool results, do NOT call the tool again."

"Never repeat a tool call that already succeeded with the same purpose."

"Only pass arguments the user actually gave you. Never invent an "
"optional argument (like a description the user never mentioned)."
```

## The smoking gun

Commit `9755202` is titled **"bench: airline domain gate + the refusal
showcase lands 1.0"** — and it is the commit that introduced
`extra_rules` carrying the cancellation-refusal rule. The celebrated
first showcase and the coaching that produced it are the same commit.
The refusal task's golden behavior — refuse cancellation outside policy,
via a spoken message — is dictated nearly word-for-word by the injected
rule. That 1.0 was earned by the rule, not the wire.

## Invalidated results — every model-scored number

Anything produced by `KopiumAgent` driving an LLM, in either domain, at
any point in the project's history:

| Claimed result | Status |
|---|---|
| Refusal showcase 1.0 (`9755202`) | **Coached** — the tested refusal is spelled out in the injected rule |
| All airline task rewards, all sessions | **Coached** — three hand-tuned rules present every run |
| All mock-domain task results | **Coached** — mock rules present since the pilot |
| refresh1/1b: koru 7/14 vs stock 12/14 ("the gate failed") | **Coached and phantom** — coached rules on one arm, plus the already-confessed token/cost accounting bug |
| Task-5 wire-teaches-quoting ~90% say() claim | **Coached** — observed under the full rulebook |
| Task-19 sequence: 4×0.0 then 2×1.0 (2026-09-27) | **Coached** — plus the first 1.0 carried an extra insurance-specific clause added that day (removed before the second) |
| Any historical "extremely good numbers" | **Coached** — same channel, whichever session produced them |

Note the direction is not simple inflation. The cancellation rule pushes
*toward refusal* — it worked against task-19's golden write. So the
4×0.0 failures are also unreadable: the harness may have been handicapped
by its own coaching. **Nothing about model-vs-harness can be inferred
from any existing run, in either direction.**

## What survives

Verification that never routes model judgment through the coached
prompt:

- Gate/interpreter pins with no LLM in the loop — refusal gate
  (900/900 forged closes), possession lifecycle, vocabulary growth
  mechanics, binding/deref mechanics.
- This session's fake-LLM marshal probes — scripted, deterministic;
  they verify the marshal honors the wire, not that the model performs.
- The marshal fixes themselves (bind-name truthfulness, speech banking,
  step-refusal notes, introspection loop, `__jsonEsc`) — real code,
  verified mechanically. They are harness correctness, not a score.
- `experiment.py` composition economics — gate-level, never instantiates
  `KopiumAgent`; not prompt-coached. (Accounting still subject to the
  usage-stamping audit.)
- The `[tN = call]` label mechanism — verified as render truthfulness;
  its claimed effect on task scores is **unmeasured** until a clean run.

## The mechanism — how it happened without a single lie

Each rule was added immediately after observing a failure on a task that
was then re-run and scored. That is training on the test set, one clause
at a time. No individual edit felt like cheating — each looked like
"teaching the agent how the environment works." The compound result is a
measured arm carrying a coach the control arm lacks.

The proximate failure this session: asked "are we overprompting?", I
audited the clause I had just written, removed it, and declared the rerun
clean — without grepping the rest of the prompt assembly for other
hand-tuned content. The rules were visible in the same file, 300 lines up.

## What a clean measurement now requires

1. `extra_rules=[]` on every measured arm — all domains, no exceptions.
2. Audit every remaining prompt element against one test: does it state
   how the wire works (syntax, encodings, channels) or when to act
   (policy, strategy, judgment)? The second kind is coaching, full stop.
   Worked examples naming real domain verbs are borderline — they teach
   encoding but also prime verb choice.
3. Re-baseline from zero. No historical reward, smoke percentage, or
   showcase survives. The stock arm's numbers stand (it was never
   coached), but all comparisons are void.
4. The "gate failed" verdict itself must be re-derived clean — the
   project's viability question is genuinely open, not answered.

## The pattern to break

Two phantom headlines in two days, same signature: a flattering or
dramatic number produced by an instrument that was never audited
end-to-end, accepted because it read plausibly. The check that was
skipped both times is the same one — before quoting any number, trace
one row of it all the way from source to cell.
