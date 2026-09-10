# Experiment — 2026-09-10: composition vs the one-line law

`frag-partial-programs` is guilty until measured innocent: *"identical goals,
multi-invocation turns vs the one-line law, cost-per-task and reliability
vote."* This is that measurement. It is small (n=3/arm, one timeout) and it
corrects part of the fragment.

## Method

One chained task — *"Open a note called exp.txt, write the line 'alpha' into
it, then close it."* — run for up to three turns, same goals and model, through
two arms:

- **composed** — the current intake: `wire:clean` keeps the whole turn and
  `std/bridge:run` sequences it (`headless/experiment.k`).
- **one-line** — the pre-flip intake from worktree `3d035e2`: `clean` truncates
  to the head, one item per turn (same `experiment.k`, only `app/wire` differs).

Runner: `python3 bench/experiment.py --n 3`. Cost = `[usage]`
prompt+completion summed per run; reliability = `exp.txt` ends as exactly
`alpha`.

## Result

| arm | completed | closed | tokens (median) | runs |
|---|---|---|---|---|
| composed | **3/3** | 1/3 | **12,630** | 11,279 / 12,630 / 14,657 |
| one-line | 1/3 | 1/3 | 13,173 | 9,440 / 13,173† / 19,461 |

† timed out at 240 s (partial capture); the other two one-line misses ended
`alpha\nalpha` — the model re-appended on a later turn.

## Reading

- **Reliability: composition wins, clearly.** Every composed run produced
  exactly `alpha`; two of three one-line runs corrupted the file by re-doing
  the append on a continuation turn. Lacking multi-item turns, the model has no
  single reply that both does and confirms the work, so it repeats it.
- **Cost: the fragment's claim is NOT supported.** The medians are within ~4%
  (12,630 vs 13,173) — noise at n=3. The fragment's "burning a full reasoning
  pass per turn" does not show up here as a large saving: the composed arm
  still spent all three turns (the program fixes the cap), and reasoning on the
  one-line continuation goals was cheap.
- **Closure failed in both arms** (1/3): the models rarely closed the note, and
  the one-line log shows why — turn 1 chained `open | append | close(handle: h)`
  against the *pre-append* handle, so the close was a no-op. Handle discipline,
  not wire shape, is the live defect.

## Caveats (what this does and does not isolate)

- The control is **old kopium intake on the current toolchain**: it enforces
  one item per turn, but a single line may still chain (`parse.wire` accepts
  arms post-`70aeb093a`). So this isolates the **multi-item-turn** effect, not
  the older "chains refused" law. The true pre-chain comparison would need a
  pre-chain `koruc`.
- The turn cap is fixed at three, so "tokens" is cost over a fixed window, not
  strict cost-to-completion. Both arms used all three turns.
- n=3 with one timeout; Muse Spark is volatile (the 08-16 lesson).

## What would sharpen it

An early-stopping task predicate (stop when `exp.txt == 'alpha'` and the bridge
holds 0) so cost-to-completion is measured directly; a larger n; and a
single-turn arm to isolate "can each shape finish the task in one reply."

## Verdict

The fragment's **reliability** half is measured and holds — composition
prevents the re-append corruption. Its **cost** half is not demonstrated; on
this task composition is roughly cost-neutral. The fragment should lose the
cost claim as an asserted benefit and keep it as an open question.
