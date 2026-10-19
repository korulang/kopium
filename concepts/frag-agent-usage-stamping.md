---
type: belief
id: frag-agent-usage-stamping
provenance: measured 2026-09-26 — refresh1b compare columns read ~6x koru-side token advantage; traced to KopiumAgent emitting AssistantMessage.text() with usage=None, so tau2's get_token_usage/get_cost counted only the user simulator
ts: 2026-09-26
---

# frag-agent-usage-stamping

**A metric column is unmeasured until the producer stamps it.** tau2's
`get_token_usage`/`get_cost` read `usage`/`cost` off each returned
`AssistantMessage`; the kopium agent built its out-message by
`AssistantMessage.text(...)`, which carries neither. The litellm response
had both — the spend lived on `response` and died at the translation to
`out`.

The consequence ran silently: every compare board's koru token/cost
columns measured only the user simulator (the one side that stamps its
own messages), and read as a ~6x kopium efficiency that never existed.
The wire's real efficiency is a live question again — answerable only by
a run landed after the stamping fix in `bench/kopium_agent.py` (the retry
loop sums all attempts onto the returned message).

The pattern generalizes and is the belief: any adapter that *translates*
the model's reply into a new message object must carry accounting fields
across the translation, or the harness will measure the silent party
(the side that never rewrites) as free. Applies to every future
bridge-arm: vocabulary agents, gate-mediated arms, anything that emits a
different message than the provider returned.

## Second vector: usage stamped on the wrong message class (2026-10-19)

The reciprocal failure, measured on the 50-task koru board: tau2's user
simulator copies `assistant_message.usage` onto each `UserMessage` it
emits (`user_simulator.py:257`), so a transcript filtered only by
"messages that carry usage" sums the *simulator's* calls into the
*agent's* column. Every compare row produced before the fix inflated
both arms by the sim's spend — agent-only comparisons like task 23's
(177,820 vs 295,464 total) exist only because the counting was rebuilt
to filter `isinstance(m, AssistantMessage)` in `bench/run_compare.py`.

Same belief, second mechanism: usage must be summed over the *agent's
own message class* — presence of a `usage` field is not evidence the
field measures the agent. Two independent contamination paths, both
silent: usage absent (unstamped) and usage misattributed (stamped onto
the sim's objects). `cached_tokens` rides along: it is a subset of
`prompt_tokens`, never additive — `uncached = prompt - cached`.
