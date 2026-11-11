# STATUS-R3 — coverage push: r2+r3 combined corpus, rebuilt transition table, edge coverage 14→17/28 strict

**Verdict: done** — 2026-11-12, uncommitted for review.

## What R3 bought

Declared-edge coverage (strict `(tor,branch)` ∈ `airline_tools.k`
{ok,error} pairs): **14/28 → 17/28** on the combined r2+r3 corpus.
Error-branch edges: **3 → 4**. Three new edges lit, all first-seen in
the R3 flights: `calculate|ok`, `list-all-airports|ok`,
`get-user-details|error`. Full per-edge table and dark-edge analysis:
`bench/scoreboard/r3-coverage.md`.

**Convention correction (carried from R2's headline):** R2 reported
"16/28 (57%)" counting all observed pairs incl. undeclared `say|`/`note|`.
Strict declared-pair coverage at R2 was 14/28 = 50.0%; the scoreboard
uses strict throughout (combined equivalent of the old convention:
20/28 = 71.4%).

## Path and spend

Same hosted path as R2: `measure.py --arms kopium`,
tau-agent-binary + `openrouter/deepseek/deepseek-v4-flash-0731`
(agent AND user sim), reasoning `medium` (binary default,
`KOPIUM_REASONING` unset — **still not in `config_key`; stamped
manually `medium` in every corpus row, same gap as R2**).
Config key identical: `kopium-1b8b218752b3` (binary sha
`0d0c81145b16…`, doc sha `5229ebae…`, tau2 head `c3398666` — all
unchanged since R2, verified before flight).

- Trials 3/4/5 via new `measure.py --trial-start 3 --trials 3`
  (seed stays `42+trial` → **seeds 45/46/47**, fresh, recorded in
  provenance). 90 runs, `--jobs 8 --ungated --suffix r3`.
- **90/90 first pass, zero error.json, zero re-flights** (R2 needed one
  re-flight for a tau2 user-sim defect; none recurred).
- **Spend: $0.9126 actual** — agent $0.7665 + user-sim $0.1461
  (flash-0731 list prices, per-run mean $0.0101). Expected ~$1.10,
  hard cap $2.00 — compliant with margin; sweep ran to completion, no
  mid-sweep stop needed.

## Split gate (verbatim)

```
$ python3 bench/check_split.py gate --tasks-file bench/split/train-30.txt
SPLIT GATE PASS — no test-20 ids in selection (30 ids)
$ python3 bench/check_split.py gate --cmd "/Users/larsde/src/tau2-bench/.venv/bin/python bench/measure.py --ids 0,1,3,4,5,7,9,10,11,12,14,15,17,20,21,23,27,28,33,34,36,38,39,40,41,42,43,46,47,49 --trials 3 --trial-start 3 --arms kopium --jobs 8 --ungated --suffix r3"
SPLIT GATE PASS — no test-20 ids in selection (30 ids)
```

Zero test-20 exposure: no runs, no transcript reads outside own run
dirs, ledger untouched. `--ungated` justification carries forward from
R2 verbatim (smoke.py's SMOKE_TASKS include test-20 ids 2/13/18;
binary verified by R1 parity + gate_probe + real runs).

## Record counts (verbatim from artifacts)

- `bench/corpus/r3-callstep.jsonl` — **1,779 rows / 90 runs / 1,440
  dispatches / 0 malformed lines / 0 problems**
  (`results/r3/collect-summary.json`).
- `bench/corpus/combined-r2r3-callstep.jsonl` — **2,790 rows / 150
  runs / 2,335 dispatches** (derived: `cat` r2+r3 corpora).
- `bench/tables/r3-transitions-combined.json` — **20 edges** over the
  combined corpus (meta: `n_dispatch_records 2335`, `n_runs 150`,
  `declared_edges 28`).

## Edge coverage — before/after

| | r2 only | r3 only | combined |
|---|---|---|---|
| declared lit | 14/28 (50.0%) | 16/28 (57.1%) | **17/28 (60.7%)** |
| error edges lit | 3 | 3 | **4** |
| tools ever dispatched | 11/14 | 12/14 | **13/14** |
| total observed pairs | 16 | 19 | 20 |

Newly lit: `calculate|ok` (n=4), `list-all-airports|ok` (n=2),
`get-user-details|error` (n=2 — the only new error edge).

**Still dark (11 declared edges), honest reasons:**

- `send-certificate|ok` + `|error` — **tor never dispatched**
  (0/2,335). Five train tasks mention "certificate" but all concern the
  one-per-payment policy; task 27's gold says don't issue. Reads as
  out-of-scope for this split, not proven unspeakable.
- 9 × `|error` edges on exercised tools — **branch never observed**:
  calculate (4 ok), list-all-airports (2), cancel-reservation (43),
  get-flight-status (57), get-reservation-details (423),
  search-direct-flight (121), search-onestop-flight (42),
  update-reservation-baggages (21), update-reservation-passengers
  (8). None proven unspeakable — error branches demonstrably fire
  (4 lit); these are sampling gaps. `get-reservation-details|error`:
  423 ok dispatches, zero errors — the deepest dark edge.

Per-edge counts, next-verb distributions, and branch histograms:
`scoreboard/r3-coverage.md` tables + `results/r3/coverage-*.json`.

## Context numbers (combined corpus — NOT coverage claims)

- Reward 115/150 = 76.7% (r2 49/60, r3 66/90: t3 23/30, t4 24/30,
  t5 19/30). Inside the ±3/30 noise floor — reported as counts, not a
  delta claim.
- **First silent failure observed**: `task39/trial4` — reward 0 with
  zero surprise events (r2 was 0/11). Combined silent-failure rate
  1/35 = 2.9%.
- New undeclared pair `abandon|abandoned` (n=1, r3-only) — same class
  as `note|`/`say|`, not a `pub tor` in airline_tools.k.
- `parse-error` item event appeared once in r3 (r2 had zero).
- Predictive row unchanged at 46.5% vs 46.7% branch-blind —
  `_predictive` trains trial0→tests trial1 only (r2 slice); no lift.

## Files

New/changed (nothing committed):

- `bench/measure.py` — **modified**: `--trial-start` flag (trials
  3/4/5 without re-flying 0/1; seed formula unchanged).
- `bench/r2_analysis.py` — **modified**: `collect --trial-min/--trial-max`;
  new `coverage` subcommand (declared-edge miner + dark-edge
  classifier). Existing subcommands untouched.
- `bench/results/r3/sweep/` — 90 raw run dirs + config.json (48M;
  `results/` is gitignored).
- `bench/results/r3/{collect-summary,coverage-r2,coverage-r3,
  coverage-combined,scoreboard-r3-raw,scoreboard-combined-raw}.json`
- `bench/results/r3-sweep.log`, `results/measure/summary_r3.csv`
- `bench/corpus/r3-callstep.jsonl`, `bench/corpus/combined-r2r3-callstep.jsonl`
- `bench/tables/r3-transitions-combined.json`
- `bench/scoreboard/r3-coverage.md`, `bench/STATUS-R3.md`

`git status`: ` M bench/measure.py`, ` M bench/r2_analysis.py`, plus
untracked `?? bench/corpus/{r3-callstep,combined-r2r3-callstep}.jsonl`,
`?? bench/tables/r3-transitions-combined.json`,
`?? bench/scoreboard/r3-coverage.md`, `?? bench/STATUS-R3.md`.
Pre-existing untracked files untouched. No commits made.

## Unverifiable / caveats

- "Unspeakable" is unproven for every dark edge — the miner measures
  observation, not tool-side possibility. send-certificate's darkness
  is consistent with split scope but that's inference from task text,
  not a gate-level proof.
- Reward figures are single-series hosted-path numbers inside the
  measured noise floor; edge counts are the reliable claim.
- `KOPIUM_REASONING` remains unstamped in `config_key` (provenance gap
  carried forward — stamped manually, same as R2).
- `_predictive` still scores only the r2 trial0→trial1 slice; a
  combined-corpus predictive row was not built (not this brief's
  deliverable).
- The r3 sweep log carries tau2 DEBUG chatter incl. user-sim message
  text — it's inside gitignored `results/`, same as R2's logs.
