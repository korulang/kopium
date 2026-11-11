# KNOWN-CONFLICTS — test-20 tasks the corpus flags

Source swept: `concepts/` + repo `*.md` for policy-vs-gold / unwinnable /
gold-conflict claims, anchored on `concepts/frag-policy-versus-gold.md`
(the fragment the measurement methodology §4.8 cites for "known-unwinnable
tasks listed up front").

## Flagged tasks

| task | in split | conflict | source |
|---|---|---|---|
| 39 | **train-30** | Gold requires cancelling `MSJ4OA` (insurance: yes); written policy makes cancellation reason-conditional (health/weather) and the sim never supplies one. Policy-faithful agents score 0.0 — measured under muse, deepseek, GLM. | `concepts/frag-policy-versus-gold.md` |

## Test-20 status

**No test-20 task id is flagged as a policy-vs-gold conflict in the
corpus docs.** The only flagged task (39) sits in train-30, so it does
not distort holdout interpretation — but it does mean train-side 0.0s on
39 are not automatically agent faults (frag: "a 0.0 on a
policy-application task is not automatically an agent fault").

Adjacent task mentions checked and ruled out as policy-vs-gold conflicts:
task 19 (`bench/CONTAMINATION-2026-09-27.md` — coached-prompt
contamination, not a gold/policy disagreement), task 32
(`concepts/frag-error-is-a-branch.md` — error-branch flattening, not a
gold conflict), SCORECARD.md task rows (run outcomes, not flagged
conflicts).

**Unmeasured:** whether any test-20 task has a gold-vs-policy tension the
corpus has not yet documented. Absence here means "no doc flags it," not
"checked and clean" — per methodology §4.8, newly discovered unwinnable
test tasks get listed here when found, never dropped after the fact.
