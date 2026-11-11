# R3 coverage — transition-table edge coverage, r2+r3 combined corpus

Corpus: `bench/corpus/r2-callstep.jsonl` (1,011 records / 60 runs) +
`bench/corpus/r3-callstep.jsonl` (**1,779** records / 90 runs) =
`bench/corpus/combined-r2r3-callstep.jsonl` (**2,790 records / 150 runs /
2,335 model dispatches / 0 malformed lines**).
Transition table: `bench/tables/r3-transitions-combined.json` (20 edges).
Declared-edge miner: `r2_analysis.py coverage` →
`bench/results/r3/coverage-{r2,r3,combined}.json`.
Configuration: unchanged from R2 — tau-agent-binary sha256
`0d0c81145b16…`, model `openrouter/deepseek/deepseek-v4-flash-0731`
(agent + user sim), reasoning `medium` (binary default,
`KOPIUM_REASONING` unset — still absent from `config_key`, stamped
manually in corpus rows), seeds 42+trial → R3 trials 3/4/5 = seeds
45/46/47, config key `kopium-1b8b218752b3`.

Denominators: "dispatch" = model-origin record with `verb != ""`;
edge = `(tor, branch)` pair; branch = `payload.branch` else `branch`
else `""`. Declared set = 14 tools × {ok,error} mined from
`airline_tools.k` = **28 edges**.

## Coverage before → after

| Corpus | Runs | Dispatches | Declared edges lit | Coverage (strict) | All observed (tor,branch) pairs |
|---|---|---|---|---|---|
| r2 only | 60 | 895 | 14 / 28 | **50.0%** | 16 |
| r3 only | 90 | 1,440 | 16 / 28 | 57.1% | 19 |
| **r2+r3 combined** | **150** | **2,335** | **17 / 28** | **60.7%** | **20** |

**Convention note (honest correction to the R2 headline):** R2's
"16/28 (57%)" counted *all* observed table edges — including the two
undeclared pairs `say|` and `note|` — over the 28 declared pairs.
Strict declared-pair coverage at R2 was **14/28 = 50.0%**. The
combined-corpus numbers above use the strict convention throughout;
the equivalent R2-convention figure for combined is 20/28 = 71.4%.

New declared edges lit by the R3 flights (3):

- `calculate|ok` — first-ever dispatches of `calculate` (n=4, all ok)
- `list-all-airports|ok` — first-ever dispatches (n=2, all ok)
- `get-user-details|error` — **new error-branch edge** (n=2; tor total
  153 dispatches: 151 ok / 2 error)

Error-branch coverage: **3 → 4 of 14 possible** (lit:
book-reservation, get-user-details, transfer-to-human-agents,
update-reservation-flights).

## Per-edge table (combined corpus)

| Edge | dispatches on branch | top next tor | tor dispatches | tor branch hist |
|---|---|---|---|---|
| `book-reservation|error` | 5 | say | 25 | ok 20 / error 5 |
| `book-reservation|ok` | 20 | say | 25 | ok 20 / error 5 |
| `calculate|error` | **0 — dark** | — | 4 | ok 4 |
| `calculate|ok` | 4 | calculate | 4 | ok 4 |
| `cancel-reservation|error` | **0 — dark** | — | 43 | ok 43 |
| `cancel-reservation|ok` | 43 | say | 43 | ok 43 |
| `get-flight-status|error` | **0 — dark** | — | 57 | ok 57 |
| `get-flight-status|ok` | 57 | say | 57 | ok 57 |
| `get-reservation-details|error` | **0 — dark** | — | 423 | ok 423 |
| `get-reservation-details|ok` | 423 | say | 423 | ok 423 |
| `get-user-details|error` | 2 | say | 153 | ok 151 / error 2 |
| `get-user-details|ok` | 151 | say | 153 | ok 151 / error 2 |
| `list-all-airports|error` | **0 — dark** | — | 2 | ok 2 |
| `list-all-airports|ok` | 2 | say | 2 | ok 2 |
| `search-direct-flight|error` | **0 — dark** | — | 121 | ok 121 |
| `search-direct-flight|ok` | 121 | say | 121 | ok 121 |
| `search-onestop-flight|error` | **0 — dark** | — | 42 | ok 42 |
| `search-onestop-flight|ok` | 42 | say | 42 | ok 42 |
| `send-certificate|error` | **0 — dark** | — | **0** | — |
| `send-certificate|ok` | **0 — dark** | — | **0** | — |
| `transfer-to-human-agents|error` | 2 | say | 52 | ok 50 / error 2 |
| `transfer-to-human-agents|ok` | 50 | say | 52 | ok 50 / error 2 |
| `update-reservation-baggages|error` | **0 — dark** | — | 21 | ok 21 |
| `update-reservation-baggages|ok` | 21 | say | 21 | ok 21 |
| `update-reservation-flights|error` | 3 | update-reservation-baggages | 32 | ok 29 / error 3 |
| `update-reservation-flights|ok` | 29 | say | 32 | ok 29 / error 3 |
| `update-reservation-passengers|error` | **0 — dark** | — | 8 | ok 8 |
| `update-reservation-passengers|ok` | 8 | say | 8 | ok 8 |

Tools dispatched at least once: **13 / 14** branched tools;
`send-certificate` is the only tool never dispatched in 150 runs.
Undeclared pairs observed: `say|` (1,302), `note|` (49),
`abandon|abandoned` (1 — first seen in R3; not a `pub tor` in
`airline_tools.k`, same class as `note`).

## Dark edges — why (11 remain)

All 11 are **never observed**, none proven unspeakable. Split by
exposure:

- **`send-certificate|ok` + `send-certificate|error` — tor never
  dispatched (0/2,335 dispatches).** Five train-30 task definitions
  mention "certificate" (tasks 14, 20, 23, 27, 38) but every mention
  concerns the one-certificate-per-payment *policy*; task 27's gold
  explicitly says the agent must NOT issue one. Consistent with the
  tool being out-of-scope for this split's task distribution — a
  tool-selection gap, not evidence the edges can't fire.
- **9 × `|error` edges — branch never observed on an exercised tool:**
  calculate (4 ok dispatches), list-all-airports (2), cancel-reservation
  (43), get-flight-status (57), get-reservation-details (423),
  search-direct-flight (121), search-onestop-flight (42),
  update-reservation-baggages (21), update-reservation-passengers (8).
  Error branches are speakable in principle — 4 are lit — so these are
  sampling gaps: the model+sim path simply hasn't produced a failing
  call for these tools yet. `get-reservation-details|error` is the
  starkest: 423 ok dispatches, zero errors.

## Context rows (combined corpus, not coverage claims)

| Row | Value | Note |
|---|---|---|
| Dispatches | 2,335 model-origin / 150 runs | r2 895 + r3 1,440 |
| Train reward | 115 / 150 = 76.7% | r2 49/60, r3 66/90 (t3 23/30, t4 24/30, t5 19/30) — inside the ±3/30 noise floor; not a delta claim |
| Silent-failure rate | 1 / 35 reward-0 = 2.9% | r2 was 0/11; the one silent fail is `task39/trial4` (31 dispatches, zero surprise events) — first observed instance. **Caveat:** task39 is the documented policy-vs-gold unwinnable task (`bench/split/KNOWN-CONFLICTS.md`) — a policy-faithful run scores 0 with clean wire by construction, so this may be an expected-0 miscounted as silent failure rather than a detection miss. Exclude-or-annotate known-unwinnable tasks before quoting this rate |
| Surprise events | stall 54, armed-mismatch 11, refusal-dispatch 6, unarmed-outcome 4 | stall = repeat call-identity within a run |
| Item events | residue 453, dispatch-error 6, validation-error 1, parse-error 1 | parse-error first seen in r3 (n=1) |
| Predictive top-1 | 46.5% vs 46.7% branch-blind | unchanged — `_predictive` still trains trial0→tests trial1 (r2 slice only); no lift |
| Spend (r3 sweep) | **$0.9126** (agent $0.7665 + user-sim $0.1461) | cap $2.00; expected ~$1.10 |

Coverage claims here are **edge counts**, not reward deltas — the
±3/30 noise floor (`frag-the-noise-floor-is-three-tasks`) does not
apply to them; it does apply to every reward number above.
