---
type: belief
id: frag-the-response-is-half-the-receipt
provenance: kopium bench 2026-10-12 — six-loss diagnosis on the V4.1 board
  stalled on request-only receipts; write-response landed and every loss
  became classifiable
ts: 2026-10-12
tags: [kopium, bench, receipts, observability]
---

# The response is half the receipt (belief)

A `call_NNN.json` that holds only the request body hides the turn that
matters most — the last one. The V4.1 board's six koru losses could not be
classified from requests alone: tasks 11, 19, and 23 all ended with the
required action undispatched and the model's final emission existing
nowhere on disk. The `wire>` stderr line existed only in the run log a
grep had already filtered. "The session ended mid-action" was the entire
diagnosis the artifacts could support.

`write-response` pairs `resp_NNN.txt` with each `call_NNN.json` — the raw
wire text the model emitted for that call, at the same sequence number.
Under it the same three ambiguous losses each resolved to a class: task 18
pinned `gift_card_3481935` as `payment_id` on all five refunds (wrong
argument); task 23's last response was a confirmation-ask instead of the
three bookings (stall-before-execute); task 7's final `say:` carried a
$708 total where the criterion wanted $1,628 (communication miss).

The ruling: a loss is a failure class waiting for evidence, not a score.
A receipt that cannot show the last emission is an instrument that stops
one turn short of the answer — and request-only capture had been that
instrument for every board that preceded this one.
