---
type: belief
id: frag-conversation-history-is-not-wire
provenance: kopium bench 2026-11-14 — task0 history audit: raw wire programs and JSON result reports were observed as user-role transcript messages, so the model could not remember what it said or did; say was a value tor minting rN; repeated identical calls returned ok payloads with buried watch text
ts: 2026-11-14
tags: [kopium, transcript, say, history, no-op, watch]
---

# Conversation history is not the wire (belief)

Koru is the action language, not the conversation language. The transcript the
model reasons over must be ordinary messages — user text, assistant say text,
tool calls, tool results — not the serialization that produced them. `say` and
`note` are emit-only void tors: they reach the user or observer and return
nothing, so they never mint a durable `rN`. A repeated call that returns an
identical result is a no-op: for the agent it is an error branch that says "you
already hold this data," not an ok payload with buried teaching. The wire
program is how actions are encoded; history is what the agent remembers.
