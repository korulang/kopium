# challenger-1 — the seed was modeling the collapse

## Autopsy (receipt-level, failing run `20261112T124357Z-task10`)

Oracle: `receipts/call_011.json` (last request body, 35 messages) +
`callsteps_*.jsonl` + `resp_*.txt`.

The run had `KOPIUM_DEMO=1` with the pre-fix demo seed. Messages 7–10 of
every request body show the exemplar the model copied:

```
assistant: get-user-details(user_id: "SOPHIA_SILVA_7557") | ok u |>
           say(text: "Found you, {{ u.name.first_name }}!")
```

`{{ u.name.first_name }}` is a two-level splice — the wire lifts ONE field
(`{{ u.user_id }}` works; deeper paths dispatch-error "carries no field").
The seed taught a program the gate always refuses.

Failure chain, all receipt-verified:

1. Turn 1: `get-reservation-details(reservation_id: "your_reservation_id")`
   — literal placeholder → `unhandled-branch: error` → `say` with unbound
   `{{ r.* }}` splices → dispatch-error. Rejected.
2. Turns 2–3: `{{ f.origin }}` / `{{ r.flights[0].* }}` — field access on
   LIST-bound values and multi-level/indexed paths → dispatch-error each.
3. Turns 4–9: the model regurgitates the demo's `{{ u.name.first_name }}`
   verbatim, six identical `get-user-details` + failing `say` programs —
   a zero-information loop (the `[watch]` identical-result teaching fired
   once, buried in payload JSON, and changed nothing).
4. `observer: 8 consecutive refused replies` → edge question "In one line:
   what were you trying to do?" → model answers in PROSE → residue strike
   (bare prose always strikes; the observer exemption covers only
   note-headed residues) → 9 → same prose → 10 →
   `die("the wire rejected 10 consecutive replies")` → FATAL.

Sibling task-3 runs (`20261112T121759Z-task3`, `…T123438Z-task3`) are the
same specimen: `{{ u.name.first_name }}` ×8 + prose ×2 → FATAL, reproduced
deterministically on rerun.

## What I tried first (documented negative)

Splice-rule hint appended to `dispatch-error`/`?partial` reports via a new
`app/tau_wire:dispatch-note` tor — teaches the grammar at the failure
moment. Rebuilt, replayed task 10 (`20261112T161737Z-task10`): hint fired
and was model-visible, run still FATALed — this replay's driver was
placeholder-arg + empty-generation + prose-answer, not the splice loop.
Reverted; not part of the submission.

## Isolation experiments (all local, qwen2.5-coder:14b, temp 0)

| run | env | result |
|---|---|---|
| `20261112T161021Z-task10` | HEAD b6fb18d, KOPIUM_DEMO=1 | **FATAL** (baseline — HEAD still collapses) |
| `20261112T161737Z-task10` | + splice-hint | FATAL (negative, above) |
| `20261112T162129Z-task10` | no demo flags | survived, 20 calls, reward 0.0 |
| `20261112T162507Z-task10` | KOPIUM_DEMO_WIRE=1 | survived, 15 calls, functional trajectory |
| `20261112T162746Z-task10` | **fix, KOPIUM_DEMO=1** | **survived, 15 calls** |
| `20261112T162933Z-task3` | **fix, KOPIUM_DEMO=1** | **survived, 15 calls** |

## The fix — smallest domain-general diff

`bench/tau-agent.k`, `demo-seed`: delete the prose-collapse exemplar
(4 `observe` lines: human asks → assistant replies PROSE → "no koru
program" refusal → assistant `say` recovery). The seed keeps the
wire-only error→retry exchange (`get-user-details` not-found → corrected
id → ok), which is now byte-identical in shape to `demo-wire-seed`.

Why it generalizes: the exemplar was not teaching recovery — it was
modeling the failure mode in the agent's own voice. A transcript that
shows "prose → refusal → recover" teaches the model that emitting prose
when stuck is a normal move; at strike-edge the observer's question
("what were you trying to do?") then reliably harvests prose answers,
each a guaranteed strike. Removing the prose turn leaves the recovery
demonstration intact and removes the attractor. No task data, no answer
keys — it is harness-seed hygiene, not doctrine.

Diff: `bench/tau-agent.k` only, +1/−5.

## Done gates

- [x] Autopsy from `call_*.json` request bodies (not trajectory)
- [x] Minimal fix: one file, 5 deleted lines
- [x] Task 10 replay: no FATAL — `results/runs/20261112T162746Z-task10/`
      (reward 0.0 reported; gate was no-prose-collapse — COMMUNICATE 1.0,
      full functional trajectory: lookup → confirm → search → update →
      calculate → finalize)
- [x] Task 3 replay: no FATAL — `results/runs/20261112T162933Z-task3/`
      (reward 0.0; died on a `calculate` expression loop — a different,
      non-collapse failure class)
- [x] `gate_probe.py` 24/24, `guides-replay.py` 93/93 + 3 dark — green
      after rebuild (`koruc tau-agent.k && mv a.out tau-agent-binary`)

## Honest limits

- n=1 per arm at temp 0; user-sim is nondeterministic — this is a signal,
  not a rate. The mechanism claim (prose exemplar → collapse attractor)
  is supported by the 2×2 env evidence above, not by statistics.
- The packaged run's *proximate* loop was splice-path failures; HEAD had
  already fixed the path-poison (`{{ u.user_id }}`, DEMO_USER_0001,
  one-level guide sentences, placeholder-arg guard). What still killed
  replay was the collapse-mode exemplar — same terminal class
  (prose-collapse FATAL), different first cause.
- `demo-wire-seed`/`demo-wire-gate` (KOPIUM_DEMO_WIRE) now seed identical
  content to `demo-seed`; left in place — it is the arm-B2 experiment
  hook, not mine to retire.
