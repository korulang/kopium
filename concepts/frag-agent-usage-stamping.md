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
