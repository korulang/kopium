---
type: belief
id: frag-oracle-coverage
provenance: live thread 2026-09-23 — "do we have strong enough oracles? can we
  see if we're succeeding or failing yet?" answered against the tree, not memory
ts: 2026-09-23
---

# Oracle coverage is layered: falsifiable at the runtime, measured-losing at
# the benchmark, human-eyeball at the live layer

The repo's oracles are not uniformly strong — they are strong exactly where
the substrate is deterministic and weak exactly where the interesting
findings live.

**Runtime layer — strong.** Koru regression pins falsify before trusting;
the refusal gate refuses 900/900 forged closes; bridge-mirror mapped all
seven interpreter↔compiler deltas to zero; `harness-check.py` is one exit
code over 24 named decisions. These oracles see failure and have repeatedly
driven fixes.

**Benchmark layer — exists, and it saw us lose.** `bench/run_compare.py`
runs kopium's gate against the stock LLMAgent on tau2 airline, same model,
same tasks, graded by the benchmark's own oracle. Aug 15–16: reward 10/28
koru vs 25/28 stock — while spending 5.8× fewer tokens and 3.5× less cost.
This is the comparison that matters for "are we succeeding": an oracle that
can say no, that already said no, and that is now a month stale — it
predates the wire flip, holes 6–9, and derived field-membership. A stale
winning number would be vanity; a stale losing number is still information,
but the refresh is owed.

2026-09-25: the refresh stopped being "owed" and became **the gate**. The
project's continuation criterion is now stated on the scorecard — fruit is
reward moving decisively off 10/28 toward 25/28, attributable to the wire
flip and landed holes, visible in the trajectory census not just the digit.
A refreshed ~10/28 ends the shared-axis claim honestly and demotes kopium
to a category claim (capability grammar, growth, enforcement the stock
shapes can't express) — which does not pay rent on a benchmark it wasn't
designed for. Measurement and continuation are the same decision here.

**Live layer — weak.** Challenge done-gates are mechanical in the brief but
checked by a human reading the transcript. The disk verdict is `cat` plus
judgment. A dead upstream stream is recorded as "the model did not emit
Koru" — a mislabeled failure no gate can tell from real silence (measured:
5 of ~18 turns lost in the double-entry-armed replay). And nothing checks
whether what the model *says* is true — the `HandleNotHeld` confabulation
was caught by a human reading, not a checker.

**Aggregation — absent.** Catalog entries are standalone witnesses. No
flake rate, no turn-success rate, no tokens-per-goal trend exists; n=1
replays produce witnesses, not rates. The experiment machinery
(`bench/experiment.py`, n=10–15 arms) proves the repo knows how to count —
the live challenges just don't count.

The pattern worth holding: **pins for the machine, prose for the agent.**
Every gap named here is a buildable artifact — a transcript verifier, an
expected-state sidecar, a catalog rollup, a baseline refresh — not a
methodology problem. The discipline that found the gaps (regression-first,
falsify-the-pin) is already the repo's habit; the live layer simply hasn't
been pinned yet.

An open question this belief deliberately does not answer: whether
"success" for the live layer even has a stable definition — a transcript
can witness an event but only a *rate* answers "does the model do this,"
and the challenge format currently produces witnesses. Replays that need
rates (does steering move the define rate?) need n, and the briefs don't
yet say when.

**2026-10-12: the oracle was reading a throttle, not the wire.** Every
run_compare board through 2026-10-11 compared stock-thinking against
koru-silent — `tau_wire.kz` sent `reasoning: effort none` while the stock
agent ran the provider default, measured live: 40-97 reasoning tokens per
call vs 0. The ~8-task gap was substantially that asymmetry, not surface.
Under `KOPIUM_REASONING=medium` plus a bounded `max_tokens` (16384 — the
unbounded 100000 budget wedged the wire into 900s watchdog deaths on three
tasks), koru scored 23/29 vs stock 27/29, and three of four systematic
losers flipped (task 1's first win in eight trials, 20, 21; task 14 still
fails on certificate-policy fidelity). The gate's verdict stands updated:
the wire at full reasoning parity sits at top of its band; the residual
four-task margin is single-trial, unproven either way. The lesson the
concept now carries: an oracle that grades a surface is only as honest as
the decode budget both arms are given.
