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

## Evolved 2026-10-11 (same day, second pass) — the price was mismeasured

The morning's "the concession costs ~4-5 tasks" did not survive the full
board. It was measured on the 10 tasks the current binary *loses* — a
regression-selected subset where re-flying at ~60% true rate predicts
~6/10 for any binary; era 7/10 and nodeliv 6/10 were the noise floor,
not a smoking gun. Full 29-task three-arm, same provider/hour/budget:
board-era 23/29, today-minus-the-line 18/29, today 17/29. The verdict
line's isolated cost is **-1, inside single-trial noise (measured ±5)**.

The regression driver moved: the era→today gap is mostly the
colon-block grammar change (koru `f8b508985`), which rewrote the
taught form (`say(text: "...")` → `say:` blocks) and fixed real
segmenter shredding — while nobody re-ran win rate. Delivering bound
prose stays defended on the original grounds (it absorbs the dominant
residue class) and the revert case is now weak; the open defect it
surfaced is different — colon-form `note:` makes every line an item,
and one reply ran 3,645 items to the watchdog. The surface wants an
items-per-turn cap, not a revert.

## Evolved 2026-10-11 (third pass, after trial-2s) — there was no regression to price

The afternoon's "−5 to colon-block, −1 to the line" did not survive the
trial-2 arms: today's binary re-flew to **23/29** (was 17), era re-flew
to 21 (was 23). Both binaries sit ~20–23; the entire era-vs-today dip
was a bad draw inside a ±4–6 single-trial band. And the era prompt,
transplanted verbatim onto today's binary, scored 16 — prompt text is
exonerated on the era axis too.

What the concession actually costs: nothing the instrument can resolve.
It fires ~40×/board and holds the 189-rejected-turns absorption it was
built for. The day's real findings are elsewhere: an unbounded
items-per-turn surface (3,645-step wedge) and — mined straight out of
the `note:` corpus — the model cannot distinguish user prose from wire
reports in the flat `role: "user"` channel. The channel itself was the
self-report instrument this whole time.
