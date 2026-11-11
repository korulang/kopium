---
type: belief
id: frag-the-noise-floor-is-three-tasks
provenance: R2 commission 2026-11-11 — 30 identical-input re-flights of
  train-30 (same binary sha, same seed 42, temp 0, byte-identical sim
  inputs) produced reward flips on tasks 1, 34, 42
  (bench/results/r2/noise-floor/comparisons.json)
ts: 2026-11-11
---

# The noise floor is three tasks: temp-0 + seed is not deterministic
# end-to-end, and ±3/30 is the smallest effect this bench can see

We assumed determinism was available for free — fix the seed, set temp
0, rerun, diff. R2 measured it: it isn't. Thirty train-30 tasks re-flown
with byte-identical configuration diverged anyway — provider-side
nondeterminism plus the user sim's own sampling walk trajectories apart.
Only 2 of 30 runs produced an identical dispatch signature; dispatch
count differed by a mean |Δ| of 3.6 (max 14); surprise-event totals moved
87 → 114 across the pair.

The consequence is a floor, not a footnote: **any reward delta smaller
than ~3 tasks out of 30 is inside measurement noise on this bench.** A
guide that "improves" one task, a threshold tweak that moves two, a
prompt change with a 5% swing — none of it is distinguishable from
rerun variance at single-trial resolution. The methodology's demand for
repeated trials and held-out splits was right; R2 is the receipt.

What this does NOT say: the system is hopeless. The floor is a property
of the hosted inference path (deepseek-v4-flash-0731 + LLM user sim),
not of the gate — the gate itself is deterministic (gate_probe 24/24,
parity identical). What varies is everything downstream of it. And 3/30
is a floor on *this* model pair at *this* task count — a stronger model
or a deterministic sim would lower it, and the floor should be re-measured
whenever either changes, because the floor is part of the instrument.

Practical rulings this belief buys:

- Scoreboard deltas get error bars or they don't get reported.
- Guide/promotion claims need either multi-trial aggregation or an
  effect size above the floor — cassette replay at firing sites is the
  cheaper falsifier precisely because it sidesteps run-level variance.
- The noise floor itself is a tracked metric: if it drifts up (model
  change, sim change), every historical comparison silently degrades.
