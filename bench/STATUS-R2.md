# STATUS-R2 — noise floor: train-30 re-flights → corpus + transition table + first scoreboard rows

**Verdict: done** — 2026-11-11, uncommitted for review.

## Path chosen and spend

**Hosted tau-agent path** (`measure.py --arms kopium`,
`tau-agent-binary` + `openrouter/deepseek/deepseek-v4-flash-0731` for
agent AND user sim). Chosen over the local llada path because the
measurement needs `(tor,branch)→next` transitions and reward-bearing
sessions: the local LLaDA2.2-mini agent is demonstrably not there —
its only airline evidence (4 task-14 runlogs, 2026-11-09..11) is
reward 0/0/0/None with parse-error-dominated records and ~3–7 gen
calls before death; a transition table mined from it would be a stub,
not "the first real measurement artifacts." The hosted path is also
the corpus being regenerated (proposal build-order 1: "regeneration
on train-30 with the current binary" — the 534-receipt corpus was
produced by this path).

**Spend: $0.7123 total** — agent $0.6248 + user-sim $0.0875
(flash-0731 list prices, 60-run sweep; re-flight 30 runs ≈ $0.36,
included in per-run figures below). No other billed resources.

## Runs

- Sweep: `measure.py --ids <30 train ids> --trials 2 --arms kopium
  --jobs 8 --ungated --suffix r2` → 60 runs, seeds 42/43,
  config key `kopium-1b8b218752b3`. **59/60 first pass; task43/trial1
  died on an empty user-sim UserMessage (tau2-side
  `ValueError: UserMessage must have either content or tool_calls`),
  re-flown clean.**
- Noise floor: all 30 trial0 `sim.json` deleted post-sweep →
  `--trials 1` re-flight, byte-identical inputs (same seed 42, same
  binary, temp 0).
- **`--ungated` justification:** `smoke.py` cannot run — its
  SMOKE_TASKS {2,13,14,18,40} include test-20 ids 2/13/18, a forbidden
  exposure. The current binary (sha `0d0c81145b16…`, rebuilt for
  drain-calls after the last smoke) is verified by stronger evidence:
  R1 parity harness (11 records identical gate vs agent path),
  gate_probe 24/24, and a real task-14 run TODAY producing 30
  well-formed callsteps end-to-end.

## Split gate (verbatim)

```
$ python3 bench/check_split.py gate --tasks-file bench/split/train-30.txt
SPLIT GATE PASS — no test-20 ids in selection (30 ids)
$ python3 bench/check_split.py gate --cmd "python3 bench/measure.py --ids 0,1,3,...,49 --trials 2 --arms kopium --jobs 4 --ungated"
SPLIT GATE PASS — no test-20 ids in selection (30 ids)
```

Ledger untouched (0 bytes) — zero test-20 exposure: no runs, no
transcript reads, no `record` calls.

## Artifacts

- `bench/results/r2/sweep/` — all 60 run dirs preserved (receipts +
  callsteps + session.json + sim.json + run.json), 28M
- `bench/results/r2/noise-floor/reflight/` — 30 re-flown trial0 dirs;
  `comparisons.json` — 30 pairwise noise-floor diffs
- `bench/results/r2/collect-summary.json`, `scoreboard-raw.json`
- `bench/corpus/r2-callstep.jsonl` — **1,011 records**, provenance-
  stamped (task/trial/seed=42+trial/run_dir/binary_sha/model/reasoning)
- `bench/tables/r2-transitions.json` — **16 edges** over 895 dispatches
- `bench/scoreboard/r2-first-rows.md` — lit rows + noise floor
- `bench/r2_analysis.py` — the miner/ scorer (collect/transitions/
  scoreboard/noise subcommands)

## Key numbers (verbatim from artifacts)

- Records: 1,011 across 60 runs; **0 malformed/missing-schema lines**
  (every record carried all 24 fields — the R1 coverage invariant held
  on every real run).
- Dispatches: 895 model-origin; item events: residue 115,
  dispatch-error 1, validation-error 1.
- Rewards: 49 pos / 11 zero (81.7%); trial0 26/30, trial1 23/30.
- Surprise: armed-mismatch 5, stall 20, unarmed-outcome 1,
  refusal-dispatch 1 → silent-failure 0/11 = 0.0.
- Edge coverage 16/28 declared (57%); error-branch edges only 3.
- Predictive: top-1 46.5% vs branch-blind 46.7% — **no lift yet**.
- **Noise floor (identical inputs, 30 tasks): 3 reward flips
  (1,34,42); pass 26→23; dispatch |Δ| mean 3.6 max 14; identical
  signature only 2/30; surprise events 87 vs 114 (|Δ| mean 4.03).**
  Temp-0+seed is NOT deterministic end-to-end.

## Findings / caveats

- `measure.py`'s `config_key` does NOT capture `KOPIUM_REASONING` —
  reasoning effort is unstamped in config.json. Stamped manually in
  corpus rows as `medium` (binary default; env unset). Provenance gap
  to fix before the next generation.
- Tau-agent path has no `run_start` event (STATUS-R1 flagged):
  provenance here = config.json + run.json + per-record stamps added
  at corpus merge.
- task43/trial1's first flight error is a tau2 user-sim defect
  (empty UserMessage), not agent/gate — recorded, re-flown, not
  patched around.
- Residue items (115) are the largest item-event class — the model
  emits non-wire lines the gate binds as residue. Counted as item
  events, not dispatch surprises; documented choice in
  r2_analysis.py.
- Predictive row is trial0→trial1 within-train — in-sample-adjacent,
  reported as the computable-from-records row only.

## git status (new files only, nothing committed)

`?? bench/r2_analysis.py`, `?? bench/corpus/`, `?? bench/tables/`,
`?? bench/scoreboard/`, `?? bench/results/r2/`, plus pre-existing
untracked (`bench/airline-gate-*`, `bench/probe_collect.db`,
`headless/*`, etc.) untouched. `bench/results/measure/` gained
`kopium-1b8b218752b3/` + `summary_r2*.csv` (untracked results tree).
