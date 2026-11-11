# R2 first rows — call_step corpus scoreboard (train-30)

First real measurement artifacts. Corpus: `bench/corpus/r2-callstep.jsonl`
(1,011 records / 60 runs / 895 model dispatches / 0 malformed lines).
Transition table: `bench/tables/r2-transitions.json` (16 edges).
Configuration: tau-agent-binary sha256 `0d0c81145b16…`, model
`openrouter/deepseek/deepseek-v4-flash-0731` (agent + user sim),
reasoning `medium` (binary default, `KOPIUM_REASONING` unset),
seeds 42+trial, tau2 `c3398666`. Series key `kopium-1b8b218752b3`.

Denominators (methodology §3): "dispatch" = model-origin record with
`verb != ""`; harness-origin records excluded from every rate.

## §6 rows lit from records + reward

| Row | Value | Notes |
|---|---|---|
| Surprise rate — armed-mismatch | 5 / 895 dispatches = **0.56%** | unhandled-branch items where the failing dispatch carried arms |
| Surprise rate — unarmed-outcome | 1 / 895 = **0.11%** | unhandled-branch, no arms written |
| Surprise rate — stall | 20 events / 60 sessions = **0.33/session** | repeat call-identity (verb+args+branch) within a run |
| Surprise rate — refusal (dispatch) | 1 / 895 = **0.11%** | `failed:true` records |
| Item-level refusals | residue 115, dispatch-error 1, validation-error 1 | zero-dispatch item records, per item not per dispatch |
| **Silent-failure rate** | **0 / 11 failed sessions = 0.0** | every reward-0 session had ≥1 surprise event |
| Edge coverage | **16 / 28 declared edges (57%)** | 14 tools × {ok,error}; 13/14 tors observed; error-branch edges: 3 (book-reservation, transfer-to-human-agents, update-reservation-flights) |
| Predictive accuracy (top-1) | **46.5% vs 46.7% branch-blind** | train trial0 → test trial1; key coverage 99.8%; top-3 76.9%. Branch conditioning shows **no lift yet** — corpus too small/smooth |
| Train reward | **49 / 60 = 81.7%** | trial0 26/30, trial1 23/30 (single trial each — inside the ±4–6 noise band) |
| Cost | **$0.7123 total** | agent $0.6248 + user-sim $0.0875 (flash-0731 prices) |

## Noise floor — identical-input re-flights (trial0, seed 42, same binary)

30 tasks flown twice with byte-identical configuration. Raw comparisons:
`bench/results/r2/noise-floor/comparisons.json`.

| Metric | Flight A (sweep) | Flight B (re-flight) | Variance |
|---|---|---|---|
| pass count | 26 / 30 | 23 / 30 | **3 reward flips** (tasks 1, 34, 42) |
| dispatches/task | — | — | mean \|Δ\| **3.6**, max **14** |
| identical dispatch signature | — | — | only **2 / 30** runs identical |
| surprise events total | 87 | 114 | mean \|Δ\| **4.03**, max **17** |

Reading: temp-0 + fixed seed is **not** deterministic end-to-end —
provider nondeterminism and the user sim diverge trajectories. The
observed ±3-task swing on 30 identical inputs is consistent with the
±4–6 single-trial band (PCA:230). Any guide/delta claim under ~4
tasks of 30 is inside this floor.

## Still dark (no emitter yet)

Escalation rate, guide-fire→recovery, guide-table churn (no guides
exist), held-out reward (test-20 untouched — ledger empty),
second-domain rates.
