# FrontierHarness Eval — local oracle-first mirror

This directory commits kopium to an external bar that cannot co-evolve with
the implementation: **FrontierHarness Eval v1 (frozen)**, model **Kimi K3**.
The full eval needs Docker + Runta + API keys and is NOT run here. What runs
here is a Docker-free wall case on the existing bench path whose verdict is
the wall exit code — one command, one number.

## Reference pin

| field | value |
|---|---|
| repo | https://github.com/frontier-harness-eval/eval |
| pinned commit | `8f11b130c30bbf76ca1f3edeea70abc773bd8d2c` (main HEAD, 2026-09-04) |
| benchmark version | FrontierHarness Eval v1, status `frozen` (`benchmark.json`) |
| model | Kimi K3, served by Fireworks |
| task sources | 21 × Terminal-Bench (`terminal-bench-2-1`) + 9 × DeepSWE (`datacurve-ai/deep-swe` v1.1) = 30 tasks |
| scoring | deterministic verifier pass/fail; `effective_cost_per_pass` = total cost / passes |
| runs | 360 evaluations (30 tasks × 12 harness configurations), 9 harnesses |
| results | `results/eval-data.json` in the reference repo |
| leaderboard | https://frontierharness.org/ |
| launch write-up | https://runta.com/blog/introducing-frontierharness-eval/ |

## The bar (published v1, Kimi K3 — recorded, not re-run)

| harness | pass rate | median cost per pass |
|---|---|---|
| Codex 0.148.0 | 66.7% | $3.47 |
| DSH Creator 0.1.0-rc.8 | 63.3% | $3.28 |
| Claude Code 2.1.237 | 63.3% | $18.34 |
| Pi 0.84.2 | 60.0% | $2.43 |
| DSH PTC 0.1.0-rc.8 | 60.0% | $4.58 |
| DSH Standard 0.1.0-rc.8 | 60.0% | $3.46 |
| Oh My Pi 17.4.0 | 56.7% | $4.75 |
| Kimi Code 0.37.2 | 56.7% | $3.65 |
| DSH Minimal 0.1.0-rc.8 | 56.7% | $4.72 |
| Exo Harness 0.1.0 | 53.3% | $1.05 |
| OpenCode 1.18.19 | 50.0% | $3.24 |
| Hermes 0.20.4 | 50.0% | $2.90 |

## Borrowed cases (provenance on every row — no mystery cases)

| local case | source repo | pinned commit | task id (suite) | closer | date | status |
|---|---|---|---|---|---|---|
| `probe_frontier_001.py` | https://github.com/frontier-harness-eval/eval | `8f11b130` | `terminal-bench/git-leak-recovery` (Terminal-Bench; medium, git/security — verifier asserts the leaked secret is ABSENT from history after rewrite) | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_002.py` | https://github.com/frontier-harness-eval/eval | `8f11b130` | harness protocol, all 30 tasks (golden checkpoint → fresh restore per task: identical vCPU/memory/disk contents/state, no cross-task contamination) | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_003.py` | https://github.com/frontier-harness-eval/eval | `8f11b130` | experiment-history flavor, all 360 evaluations retained in `results/eval-data.json` (30 tasks × 12 configs, none evicted) | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_004.py` | https://github.com/frontier-harness-eval/eval | `8f11b130` | deterministic-verifier scoring flavor, all 30 tasks (re-verifying the same work yields the same verdict) | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_005.py` | https://github.com/ShishirPatil/gorilla | `6ea57973` (verified 2026-09-05) | BFCL Simple (AST) — "one and only one function call being invoked" | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_006.py` | https://github.com/ShishirPatil/gorilla | `6ea57973` (verified 2026-09-05) | BFCL AST argument values — the emitted call matches parameter values, not just the function name | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |
| `probe_frontier_007.py` | https://github.com/frontier-harness-eval/eval | `8f11b130` | DeepSWE post-patch regression flavor, 9 × `datacurve-ai/deep-swe` v1.1 tasks (a passing test that predates the patch must still pass byte-for-byte afterward) | wall exit code (`bench/harness-check.py`) | 2026-09-05 | PASS |

What is borrowed from the experiment history is the retention
flavor: no trial evicts another. No task code, image, or verifier is
vendored — the local case re-expresses it on the bridge's own seam
(two distinct inventions coexist in one session's table; the second
define never evicts the first, see probe docstring). History pattern
per `exoharness/exo` @ `7801005e` below.

What is borrowed from the fresh-restore protocol is the starting-state
flavor: a new evaluation must not see the previous task's residue. No
task code, image, or verifier is vendored — the local case re-expresses
that absence-check on the bridge's own seam (a fresh Bridge REJECTs a
foreign invention; two live Bridges fork and diverge, see probe
docstring). Fork pattern per `exoharness/exo` @ `7801005e` below.

What is borrowed from `git-leak-recovery` is the oracle flavor: after a
rewrite, the old body must be GONE, not merely shadowed. No task code,
instruction, Docker image, or verifier is vendored — the local case
re-expresses that absence-check on the bridge's own seam (see probe
docstring). The reference verifier itself stays Docker-gated and is never
run here.

## Second oracle: VulcanBench v1-micro baseline (run, not recorded)

| field | value |
|---|---|
| repo | https://github.com/morganlinton/VulcanBench |
| pinned commit | `18a33796` (2026-09-01) |
| suite | v1-micro, 26 micro-tasks (Go/Python/Rust/TypeScript), Docker sandbox, network off |
| model | `openrouter:meta/muse-spark-1.3-contributor`, temp 0, bare loop |
| closer | deterministic hidden tests (fail-to-pass + pass-to-pass), judges disabled |
| verdict (2026-09-07) | **26/26 functional pass**, 448,280 tokens, 2,298s wall |
| card | `challenges/oracle-join/catalog/2026-09-07-vulcan-v1micro-baseline.md` |
| known gaps | security scores null (`gosec` missing from sandbox image); `cost_usd` null (contributor route unpriced) |

## Pattern provenance (borrowed, code not)

- https://github.com/exoharness/exo @ `7801005e` (2026-09-02):
  **snapshot → mutate → rewind → assert** round-trip. The probe snapshots the
  v1 dispatch, mutates via redefine, rewinds via redefine-back, and asserts
  at every stage. No exo code is vendored or imitated.

## The full Runta path (pointer only — not required, not run)

Golden checkpoint → fresh restore per task, identical vCPU/memory/disk
contents/state. Reference implementation lives in the pinned repo under
`skills/frontierharness-eval/` (`scripts/provision-golden-checkpoint.sh`,
`scripts/run-trials.sh`; Harbor 0.22.0 for Terminal-Bench, datacurve-pier
0.3.1 + deep-swe corpus @ v1.1 for DeepSWE). Requires Docker, a Runta
account, and a provider key. This slice deliberately stops at the wall case.

## Local run (zero new dependencies, zero Docker, zero API keys)

```
python3 bench/harness-check.py
```

Exit code is the verdict. The `frontier-001` row is the slice's closer.
