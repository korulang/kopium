---
type: belief
id: frag-the-harness-delivers-bound-prose
provenance: kopium bench 2026-10-07 — implicit-say smoke: a whole-prose
  reply bound at r29, re-emitted as `say:` + text, reached the user
  verbatim; the first implementation emitted `say(text: rN)` and the user
  read the literal name (Source fields never resolve bindings — koru
  519e688c4 carries the correction)
ts: 2026-10-07
tags: [kopium, wire, residue, say, harness, policy]
---

# The harness delivers bound prose — policy is not grammar (belief)

The wire gate is and stays absolute: a whole-prose reply is not wire, it
binds as residue, and the report is honest at that layer — "nothing
reached the user." But *what a bound reply does next* was never a grammar
question. It is harness policy, and it lives in the agent loop, not in
`std/bridge`.

The ruling: on a `residue` verdict carrying prose (`text` non-empty,
`observer` false), the harness emits `say: <prose>` — a real wire call
through the scope's own verb, not a backdoor. The say ledger counts it,
the transcript sees the teaching line ("the harness emitted it under
`say:` on your behalf"), and `implicit_say` in session.json makes the
concession a measured number instead of a silent one. A scope without
`say`, an observer-flagged item, or a mixed multi-item turn strikes
exactly as before — only the *whole-prose* reply soft-delivers.

Why colon form and not `say(text: rN)`: say's field is `Source`, and
Source captures literally — a bare name in that position is text. The
obeyed instruction shipped "r29" to a live user in the first smoke. The
bound prose itself carries no invocation-head lines by construction (a
line that segmented would have made the turn multi-item, not all-prose),
so `say:` + text cannot fragment.

Why the loop and not the bridge: `std/bridge` is the grammar's layer —
its verdict is the truth ("not wire, nothing reached the user"), and
every head should see the same strict boundary. The decision that bound
prose still reaches the user is the *harness being the operator* — the
same act the report used to ask the model to perform by hand, done by
the loop instead, and counted so a board can show how much of the
surface is grammar and how much is policy.

## Evolved 2026-10-11 — the concession costs ~4-5 tasks; measured, not argued

The A/B/A re-flight (`results/compare_fair28.csv` + era/nodeliv sweeps)
put a price on this ruling: identical 10 regression tasks, same provider,
same hour, same 200/10 budget — board-era binary (pre-concession)
**7/10**, current binary **2/10**, and current sources minus the single
`residue-verdict → | deliver` line **6/10**. Delivering bound prose is
the entire measured regression since the 77/100 board.

The lesson this evolution carries: the smoke gate checks integrity, not
win rate — the concession passed it (5 runs, 0 failures) because nothing
broke at the wire layer; the cost lives in what the *model learns*.
Working hypothesis for the mechanism, unproven: delivered bare prose
teaches the model it can skip `say:`, and half-protocol turns compound
into wanders and wrong writes. The open question the revert-or-redesign
decision hangs on: the concession existed to absorb the dominant residue
shape (189 rejected turns on the teach board) — is there a shape that
keeps the delivery but reimposes the protocol cost on the model (deliver
AND strike the turn), or is strictness-only the honest surface?
