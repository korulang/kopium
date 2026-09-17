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

---

# Round 2 (same day) — cost-to-completion

Round 1's cost was over a fixed 3-turn window, which inflated the composed
arm (it finished early and the program kept spending). The sharpening: a
per-turn file probe (`note-done` in `experiment.k` reads `exp.txt` after each
turn — `append` writes straight to the fd, so the bytes are visible before any
close) lets the runner sum `[usage]` **through the first turn the task's bytes
appeared**. Headroom is 4 turns; `--n 5`.

| arm | completed | median cost-to-completion | full 4-turn window | closed |
|---|---|---|---|---|
| composed | **5/5** | **3,192** | 16,817 | 3/5 |
| one-line | 3/5 | 4,203 | 14,287 | 4/5 |

Cost-to-completion (tokens): composed `[2861, 3076, 3192, 4751, 5926]`,
one-line `[2860, 4191, 4203, 4632, 5385]`.

## Reading round 2

- **Cost-to-completion modestly favors composition** (~24% median cheaper) and
  **reliability favors it** (5/5 vs 3/5). Both one-line misses are the same
  handle-discipline failure: the model emits
  `open | ok h |> append(handle: h, …) | ok |> close(handle: h)` — closing the
  **pre-append** handle, which `append` already discharged — so the note never
  closes and a later continuation turn re-appends, corrupting the file with
  `alpha\nalpha`. The wire is not at fault; the model's binding is.
- **4/10 runs hit the 240 s timeout** (2 per arm), all during a turn's stream,
  not in the harness. The timeouts still yielded valid cost-to-completion where
  the task had completed by the first turn. This flakiness bounds confidence.
- **The control is weaker than intended**: a single line may still be a chain
  (`parse.wire` accepts arms post-`70aeb093a`), so the one-line arm can complete
  a *chainable* task in one turn — it did, 3/5. The old law's remaining bite is
  therefore small for exactly the chained task the fragment names. The true
  pre-chain comparison would need a pre-`70aeb093a` `koruc`.

## Verdict round 2

Still not a clean win for the fragment's cost claim — small n, 4 timeouts, and
a control that permits chains — but the direction now leans **in** composition's
favor on both axes rather than against. Net across both rounds: composition is
**at least cost-neutral and more reliable**; a cost advantage is plausible but
unproven. The instrument is now good enough to settle it with a pre-chain
control and a larger n.

---

# Round 3 (2026-09-17) — the true pre-chain control

Rounds 1–2's control was weakened twice over: the one-line intake truncated to
the head but the *modern* `parse.wire` still accepted a single-line chain. This
round adds the arm the earlier verdicts asked for:

- **pre-chain** — kopium at `d7e5c3b` (contemporaneous with koru
  `70aeb093a~1`), compiled by that era's `koruc` (worktree
  `~/src/koru-prechain` at `511392414`). Its `parse.wire` rejects `|>`
  outright — *"chains are not wire: one invocation per turn"* — so the handle
  crosses turns as a **literal string the model reads out of the tool result
  and writes back**. `experiment.k` is the same file minus the
  `unhandled-branch` arm (the branch did not exist until the chain rung —
  dropped, not stubbed).
- The runner also gained a **strict** completion metric: cost through the
  first turn-check where the bytes are right AND the bridge holds 0. The
  lenient metric counted `alpha`-on-disk while the note stayed open —
  flattering arms that defer the close. `HOLDS_RE` was widened to also match
  the `partial` branch's `bridge holds N` phrasing (it previously undercounted
  closure on runs that ended via a partial report).

Same task, same model (`meta/muse-spark-1.3-contributor`, temperature 0),
4-turn headroom, `--n 5` × 2 batches = **n=10 per arm**. No timeouts this
round. Logs: `bench/experiment-logs/round{3,4}-n5/`.

| arm | bytes ok | closed | median ctc | median strict ctc | median window |
|---|---|---|---|---|---|
| composed  | 10/10 | 10/10 | 4,018 | 10,622 | 12,595 |
| one-line  | 9/10  | 8/10  | 4,389 | 7,369  | 10,674 |
| pre-chain | 10/10 | 10/10 | **2,161** | **3,512** | **5,462** |

## Reading round 3

- **The cost claim inverts.** Against a control where chains are genuinely
  unavailable, composition is not cheaper — it is ~3× *more* expensive on
  strict cost-to-completion (median 10,622 vs 3,512) and ~2.3× on the full
  window. The mechanism is visible in the usage lines: the composed model
  burns 2,000–3,000 reasoning tokens per turn planning and defending its
  chains (and twice paid a whole refused turn to the new unreachable-arm
  check — `unreachable 'ok' arm`, correctly emitted and correctly recovered),
  while the pre-chain model emits one invocation per turn at ~300–600
  completion tokens each.
- **Reliability is parity, not an edge.** Both surviving arms went 10/10 on
  bytes and 10/10 on closure. The earlier reliability advantage was measured
  against the *truncating* intake (one-line: 9/10 bytes, 8/10 closed — its
  misses are still the re-append corruption); against the honest serial
  control, composition buys nothing on correctness.
- What composition *did* buy: bytes landed sooner — composed wrote `alpha` on
  turn 1 in 6/10 runs vs pre-chain's earliest possible turn 2. Latency, not
  cost or reliability.
- The pre-chain arm never once attempted a chain — the era's grammar says
  "no chains (|>)" and the model obeyed it. Zero parse rejections in 10 runs.

## Verdict round 3

The fragment's **cost claim is measured false** for this task shape: serial
invocation under the one-line wire is ~3× cheaper to strict completion and
equally reliable at n=10. The **reliability** claim survives only against the
truncating intake. Scope note: the task is the minimal serial case
(open→append→close); composition's putative payoff is tasks where several
*independent* calls collapse into one turn, which this task has none of. What
this round settles: on a chainable serial task, the chain costs more reasoning
than it saves turns.

