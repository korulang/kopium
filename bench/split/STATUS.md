# STATUS — BRIEF-R0 (freeze the split + open the exposure ledger)

**Verdict: done** — 2026-11-11, uncommitted for review.

## Files created

- `bench/split/train-30.txt` — 30 ids, upstream `train` order
- `bench/split/test-20.txt` — 20 ids, upstream `test` order
- `bench/split/SPLIT.md` — provenance, selection rule, hashes, freeze statement
- `bench/split/exposure-ledger.jsonl` — 0 bytes, empty to start
- `bench/split/KNOWN-CONFLICTS.md` — policy-vs-gold sweep result
- `bench/check_split.py` — the gate (`gate` / `record` subcommands)
- `bench/split/STATUS.md` — this file

## Split source (verified, not assumed)

`~/src/tau2-bench/data/tau2/domains/airline/split_tasks.json` exists and
ships `train`=30 / `test`=20 / `base`=50 (`base` = train ∪ test).
tau2 checkout HEAD `c3398666e6559e3a063da3fc04b5acf7f941464e`; upstream
file sha256 `b22ced4d9a9850ac9aea31c53bdcb6d6009058140bd9acc7db37c1d36222ba8b`.
Only ids were read — no task content, transcripts, or gold anywhere.

## sha256 (reproduced twice, identical)

```
2b87d001d9a734f49d01f98ad56eea85825842255fb9fcd6f73dc2663d476d83  bench/split/train-30.txt
c8a9296d64c28ca3c66abe209decdc323342619dfaf71e78012c54f1c05415e1  bench/split/test-20.txt
```

## Verification outputs (verbatim)

Refuse, real empty ledger:

```
$ python3 bench/check_split.py gate 2
SPLIT GATE REFUSE — test-20 ids with no ledger line: 2
  record the exposure first: python3 bench/check_split.py record --purpose "<why>" --who "<who>" 2
exit=1

$ python3 bench/check_split.py gate --cmd "python3 bench/run_airline.py 2"
SPLIT GATE REFUSE — test-20 ids with no ledger line: 2
  record the exposure first: python3 bench/check_split.py record --purpose "<why>" --who "<who>" 2
exit=1
```

Pass after a ledger line — demonstrated against a scratch ledger via
`KOPIUM_EXPOSURE_LEDGER=/tmp/kopium-ledger-selftest.jsonl` so the real
ledger stays empty (a self-test line would be a false exposure record):

```
$ python3 bench/check_split.py record --purpose "gate self-test, no real exposure" --who "devin-cli self-check" --binary bench/check_split.py 2 6
ledger += {"date": "2026-11-11", "task_ids": ["2", "6"], "binary_hash": "d0c82dd584c9edc39b0f1003cf01f61f22b0c8a6c9b1e2c43acd37d5a9284042", "purpose": "gate self-test, no real exposure", "who_looked": "devin-cli self-check"}

$ python3 bench/check_split.py gate 2 6
SPLIT GATE PASS — test-20 ids covered by ledger: 2, 6
exit=0

$ python3 bench/check_split.py gate 2 8
SPLIT GATE REFUSE — test-20 ids with no ledger line: 8
exit=1
```

`--cmd` resolver sweep (same scratch ledger, 2 and 6 covered):

```
run_compare.py 0 50                      → REFUSE opaque (positional/all-50)
run_compare.py --ids 0,2                 → PASS (2 covered)
measure.py --ids 0,2 --trials 2 --jobs 4 → PASS (only --ids scanned; --trials/--jobs ignored)
measure.py --ids 0 --trials 2 --jobs 6   → PASS (0 test-20 ids — numeric flags not ids)
run_airline_local.py --arm warm          → PASS (0 ids; script default task 14)
run_stock.py 6                           → PASS (6 covered)
run_mock.py create_task_1                → PASS (mock domain, out of scope)
tau2 run --domain airline (no task flags)→ REFUSE, lists all 18 uncovered test ids (base=all 50)
tau2 run --domain airline --task-split-name train --num-tasks 5 → PASS
tau2 run --domain airline --task-ids 0 1 → PASS
tau2 run --domain airline --num-tasks 10 → REFUSE opaque (unordered split prefix)
tau2 play --domain airline               → REFUSE opaque (interactive split choice)
tau2 run --domain retail --task-ids 2    → PASS (non-airline domain skipped)
tau2 view                                → PASS (no task selection)
bash -c 'python3 bench/run_airline.py 8' → REFUSE (8 uncovered)
```

`--tasks-file` with comments/blanks works; real ledger confirmed 0 bytes
after all runs.

`git status`: only `?? bench/check_split.py` and `?? bench/split/` are
new; no tracked file modified. (Pre-existing untracked files —
`bench/airline-gate-*`, `bench/probe_collect.db`, `headless/*` — were
present before this task and untouched.)

## Could NOT verify / known limits

- **Ledger pass was shown on a scratch ledger**, not the real one — by
  design; the real `exposure-ledger.jsonl` is intentionally 0 bytes.
- **`--cmd` covers the selection grammars found in this repo's bench
  entry points** (`run_airline*.py`, `run_baseline.py`, `run_stock.py`,
  `run_compare.py`, `measure.py`, `wire_driver.py`, mock runners,
  `tau2 run/review/play`). An unrecognized command gets a conservative
  numeric-token scan (false refuses possible, e.g. `--trials 2`; re-run
  with `--tasks` for precision). Compound commands split on
  `&&`/`||`/`;`/`|`/newlines and `bash -c` quoting is flattened one level.
- **Result-browsing names no ids**: `tau2 view`, opening
  `bench/results/**/task2/` transcripts, or reading tau2's
  `data/simulations/` directly exposes test-20 content without any id in
  an invocation. The gate cannot see it — that exposure is honor-system
  and must be hand-recorded via `record`. Stated in the module docstring.
- **tau2 `base` ordering is unverified** (didn't read `tasks.json` —
  task content). `--num-tasks` without `--task-ids` is refused as opaque
  rather than resolved, so no ordering assumption is load-bearing.
- `KNOWN-CONFLICTS.md` verdict is "no doc flags any test-20 id" — the
  sweep covered `concepts/` + repo `*.md`; it is not a per-task audit of
  all 20 (that would require reading task content, which the hard rules
  forbid). Anything beyond the docs is marked unmeasured in the file.
