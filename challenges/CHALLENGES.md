# KOPIUM challenge registry

Standing generators for the airline harness. Each brief is sealed,
self-grounding against its own catalog, and replayable from zero.
Generated briefs come from `bench/package_failure.py <run_dir> --name
<slug>`; hand-tuned briefs are slow-clock objects (gardener acts).

| challenge | kind | specimen | status | catalog depth |
|---|---|---|---|---|
| airline-failure-replay | frame | task-10 prose-collapse FATAL (pre-fix binary) | standing — cycle 1 complete | 1 submission, 1 adopted (d1d7092) |
| task5-collapse | frame | task-5 FATAL on fixed binary — get-flight-status loop + say dispatch-errors | standing — awaiting contestant | 0 |

## Conventions

- `kind: frame` — output drains into the codebase as fixes; catalog/
  holds judged submissions (autopsy + full diff + replay receipts).
- Judging: smallest domain-general diff that survives replay wins;
  test-keyed or answer-injecting fixes fail review regardless.
- Contestants: devin-kind via herdr (free); external models via manual
  paste-back briefs (see n-grams/fable-pack/BRIEF-EXTERNAL-REVIEW.md).
- A packaged specimen is consumed when its failure class is fixed AND
  verified on replay — the challenge stays standing for the next
  specimen of the same class.
