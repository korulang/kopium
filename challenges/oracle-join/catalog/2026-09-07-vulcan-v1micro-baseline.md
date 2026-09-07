# vulcan-v1micro-baseline — deterministic outside pass/fail at micro spend

One sentence that can be wrong: VulcanBench v1-micro gives deterministic
outside pass/fail for our model at micro spend, Docker-gated.

## What ran

`vulcanbench run --suite v1-micro --model openrouter:meta/muse-spark-1.3-contributor
--no-judges --sandbox docker --max-concurrency 2` from a pinned clone in a
worktree (adopted mid-flight after the commissioning session was cancelled;
the run itself was unaffected). Suite: 26 tasks (Go, Python, Rust,
TypeScript micro-tasks), closer = hidden fail-to-pass + pass-to-pass tests,
no LLM judges.

## Verdict: 26/26 functional pass

448,280 tokens total, 2,298s wall (~38 min). Per-task functional all 1.0:

| task | total | duration_s |
|---|---|---|
| go-csv-quoting | 0.9800 | 73.2 |
| go-lru-cache | 0.9709 | 74.6 |
| go-money-allocate | 0.9682 | 118.5 |
| go-parallel-map | 0.9596 | 146.4 |
| go-stack-pop-bug | 0.9844 | 64.1 |
| go-worker-pool | 0.9869 | 126.2 |
| oss-go-m2-01 | 0.9835 | 68.1 |
| oss-go-m3-04 | 0.9836 | 60.3 |
| oss-inflection-titleize | 0.8828 | 228.1 |
| oss-py-m2-00 | 0.9794 | 18.4 |
| oss-py-m3-00 | 0.9865 | 14.8 |
| oss-ty-m2-02 | 0.9853 | 18.8 |
| oss-ty-m3-05 | 0.9883 | 19.4 |
| py-csv-export-feature | 0.9602 | 36.7 |
| py-expr-eval | 0.9469 | 82.0 |
| py-jsonpointer | 0.9535 | 64.6 |
| py-retry-refactor | 0.9102 | 86.8 |
| py-topo-sort-cycle | 0.9728 | 23.8 |
| py-ttl-cache-expiry | 0.9763 | 30.3 |
| rs-borrow-split | 0.9159 | 511.6 |
| rs-feature-gate | 0.9908 | 24.2 |
| ts-debounce | 0.9600 | 72.0 |
| ts-deep-merge | 0.9505 | 144.1 |
| ts-event-emitter | 0.9721 | 80.2 |
| ts-querystring-bug | 0.9818 | 37.0 |
| ts-schema-validate | 0.9705 | 74.2 |

## Provenance

- source repo: https://github.com/morganlinton/VulcanBench
- pinned commit: `18a33796` (2026-09-01)
- suite: v1-micro, suite-id `suite-c22d0aa0`, run dir `runs/v1micro-2026-09-07`
- model: `openrouter:meta/muse-spark-1.3-contributor`, temp 0, bare loop
- closer: deterministic hidden tests (`fail_to_pass` + `pass_to_pass`), judges disabled
- date: 2026-09-07

## Install-story verdict (the Docker dividend, already paying)

- Docker pull + sandbox build worked first try; 2-container concurrency stable.
- `gosec not on PATH` → every security score null. First honest install gap:
  the sandbox image lacks the Go security scanner, so the security dimension
  is unwitnessed, not passed.
- `cost_usd` null on every task (`model_priced: false` — our contributor
  route has no public price). Tokens are real (448k); dollars are not
  measurable through their harness. Price via our own meter when cost gates.

## What would correct this card

A re-run at a new pinned commit changing any task verdict; the security
column going non-null; a priced cost figure replacing the token-only
economics; the harness-study follow-up (same suite through the kopium
bridge) meeting or missing this bare-loop baseline.
