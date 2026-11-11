# SPLIT — the frozen 30/20 airline task partition

**Frozen: 2026-11-11. This list never changes.**

If tau2's upstream `split_tasks.json` changes, we do **not** follow it.
The holdout is frozen at freeze time; upstream drift is a fact to record,
never a reason to re-draw. A changed upstream split does not move a single
id in or out of `test-20.txt`.

## Source

- Upstream file: `data/tau2/domains/airline/split_tasks.json` in the
  `tau2-bench` checkout at `~/src/tau2-bench`
  (local HEAD `c3398666e6559e3a063da3fc04b5acf7f941464e`;
  file sha256 `b22ced4d9a9850ac9aea31c53bdcb6d6009058140bd9acc7db37c1d36222ba8b`).
- This is the split PROPOSAL-context-assembly.md §"Commission-2 deltas"
  cites (PCA:180): `train`=30 / `test`=20 / `base`=50, where `base` is
  the concatenation of the two.
- Upstream stores ids as JSON strings (`"0"`…`"49"`); the lists below
  store the same strings, one per line.

## Selection rule

Verbatim adoption, no resampling:

- `train-30.txt` = upstream `train` array, in upstream order.
- `test-20.txt` = upstream `test` array, in upstream order.
- `base` (all 50) is not frozen as a file — it is exactly
  train ∪ test and carries no independent information.

## Content hashes (sha256 of the files above)

| file | ids | sha256 |
|---|---|---|
| `train-30.txt` | 30 | `2b87d001d9a734f49d01f98ad56eea85825842255fb9fcd6f73dc2663d476d83` |
| `test-20.txt` | 20 | `c8a9296d64c28ca3c66abe209decdc323342619dfaf71e78012c54f1c05415e1` |

Reproduce: `shasum -a 256 bench/split/train-30.txt bench/split/test-20.txt`

## What the freeze covers — and what it does not

- The freeze covers **task ids only**. It says nothing about task
  content, gold answers, or transcripts — those stay behind the
  exposure ledger (`exposure-ledger.jsonl`, enforced by
  `bench/check_split.py`) per
  `n-grams/fable-pack/output/03-measurement-methodology.md` §4.
- tau2 mints no new airline tasks (methodology §4.3), so test-20 only
  shrinks via the ratchet; the file itself is still never edited.
