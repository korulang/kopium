---
type: belief
id: frag-say-is-a-write-not-a-read
provenance: kopium bench 2026-10-06 — non-blocking sayIO broke the transcript
  feed silently; the loop reads inbound only in boot, so every user message
  reaches the transcript solely via pending -> drain; smoke caught it live
  ("the result r5 is just an 'ok' acknowledgment")
ts: 2026-10-06
tags: [kopium, wire, protocol, say, pending, ledger]
---

# Say is a write, not a read — the wire turn is one assistant message (belief)

`say` was secretly a request-response: it emitted the SAY line, then blocked
reading the user's reply and returned it as its value. That made "speak and
act" structurally impossible — one wire turn could never do what stock's
assistant message does in one shot (text + tool_calls). Worse, the blocking
read was the *only* thing feeding user replies into `pending`; when say
stopped reading, replies stranded on stdin and the transcript starved —
silently, with no desync panic.

The ruling: **say is a pure write.** It emits and returns the emitted text.
Every outbound SAY owes exactly one inbound `user` line — the harness replies
per outbound, in order — so the pairing is a counter, not a coincidence:
`outstanding_user` increments per say, `callIO` debits the user lines it
meets before its result, and `pull()` at turn end collects the remainder
into `pending`. FIFO order is preserved by construction, and a non-user
line where a user line is owed panics loud instead of drifting.

The deeper belief this corrected: the 1:1 outbound:inbound contract was
implicit in say's blocking read — nobody owned the count. Any protocol
change that moves *when* a read happens must account for *who* reads, or
the stream silently reassigns the next message to the wrong consumer. A
ledger makes the coupling explicit and the desync impossible to miss.
