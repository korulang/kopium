---
name: arbiters-gauntlet
description: Run a gauntlet — an autonomous, many-round loop that closes a gap against an external reference under a mechanical closer, with the fleet driving itself between rounds. Fire whenever a run could be judged by something outside the repo: "run a gauntlet", "parity run", "port X to Y with the same coverage", "match the reference implementation", "close the gap against <existing system>", "beat the bar", or the Gauntlet day named on a walk. Also the right skill when asking whether work IS gauntlet-shaped, when picking the rung, or when a running gauntlet has plateaued. The industry calls this a "gauntlet loop" and that is the term we use — with the leash set by the rung, not by nerve.
---

# Gauntlet — the loop that drives itself, because the closer cannot be flattered

This is the **sixth door** on the walk (`../arbiters/walk.md`) and the most
autonomous instrument the method has. You hand it a reference, a closer, and a
budget, and it runs — many rounds, wide fan-out, no human between rounds. That
self-driving property is the **point of the door**, not a risk to be managed
down. A gauntlet you have to babysit is a Tactical day wearing a costume.

The whole method is otherwise human-gated, so the first thing this file owes you
is *why ADD is allowed to host a loop like this at all.*

## Why the human gate can come off — the closer is the arbiter

Read the gates in `../arbiters/judge.md` and they are all the same gate. A
passing test doesn't ratify a shape. A green suite proves the change works, not
that it was allowed. A contestant's "looks clean" is the artifact describing
itself. A critic's "ours won" is the same instrument in a different hat. Every
one of those exists because **an instrument could be flattered** — and flattery
needs judgment to sneak through.

`diff` against a golden file is not judgment. It is a fact. An oracle you did
not write, a suite delta, a byte comparison — none of them can be talked into
anything, by a contestant or by you. **Where the closer is incorruptible, the
human gate is not safety; it is friction.** Removing it is the reference
ladder's own logic followed to the end, not an exception carved out of ADD.

So the question is never "should this loop be supervised." It is **how
corruptible is the closer** — and that has an answer, per rung.

## THE LEASH IS THE RUNG

The one rule this skill exists to carry. Autonomy is not a nerve setting; it is
a function of the closer, and the reference ladder already grades closers.

| rung | closer | leash between rounds | fan-out | exit on beating the bar? |
|---|---|---|---|---|
| **1 · bit-exact** | `diff`, an oracle, a suite delta — mechanical, reproducible, no model in the path | **none — run unattended**, report at the end | **wide** (dozens; as many as the budget buys) | **yes, legitimately** |
| **2 · behavioral A/B** | mechanical but noisy or statistical — distinguishability, tolerance windows, holdout scores | walk at **batch boundaries**, not rounds | medium | on the **holdout**, never on the fitted set |
| **3 · subjective** | an LLM critic, a human ear, taste | **every round returns to the walk** | 2–4, like any contest | **never** |

**The industry's documented failure is a rung-3 loop run at rung-1 autonomy.**
In the widely-circulated game-generation runs, eleven LLM critics scored 1–10,
the average climbed 3.59 → 4.14 → 4.05 → 5.05, and *every critic in every round
still picked the real frame*. The loop never once met its own exit condition.
Nothing was wrong with the loop. The closer was rung 3 and the leash was rung 1,
so a rising number measured accumulated effort and nobody could see it.

Get the rung right and both halves of the doctrine fall out for free: on rung 1
"run until it wins" is a **correct** exit condition, and on rung 3 it is the
forced green the whole method refuses.

## Entry — name the rung, or you don't have a gauntlet

Two questions at the door, and they are the only reluctance this skill has.

1. **Is the reference admissible — named, fetchable, comparable?** Exactly which
   system or dataset (not "the state of the art"); reachable by a machine; and a
   closer that renders a verdict with no human in the loop on every round. See
   `../arbiters/scout.md`.
2. **Which rung is the closer on?** Say it out loud. A closer you cannot place
   on the ladder is a closer you have not actually specified, and the run you
   are about to fund is a Tactical day with ambition.

**Reluctance is about the SOFTNESS of the closer, never the SIZE of the run.** A
rung-1 gauntlet *should* be huge — hundreds of rounds against a mechanical
oracle is exactly the shape this door exists to serve, and being timid there
wastes the only instrument in the method that scales past the two arbiters'
attention. Being brave on rung 3 is how you get a beautiful climbing score
attached to a product nobody picked. **Small and soft is the dangerous
combination. Big and hard is the point.**

## Calibrate the closer once — the only thing that precedes the fan-out

One pull before the fleet, and it is not a ceremony round or a timid half-start:
**the closer is an instrument, and tenet 3 says you measure from the real thing,
never from its description of itself.** An unverified closer running 500 rounds
autonomously produces 500 confident wrong answers, and the autonomy that makes
this door valuable is precisely what stops you noticing.

So the calibration pull has one job: **make the closer self-certify.** It must
report its own unresolved / unclassified / can't-tell fraction, and you do not
spend a fleet until that fraction is small enough to trust. A closer with no
honesty check is not calibrated by staring at it.

The worked case is koru's JS-parity map. Run one reported **DO NOT TRUST, 29%
unclassified** — and behind that number sat three real resolution bugs
(annotation-prefixed declarations invisible to the scan, type references counted
as calls, bodyless declarations counted as blockers). Fixed, it self-certified at
**0.3%**, and the plan inverted: the module that looked like "reimplement 8.7
KLOC of database" turned out to be a compile-time transform and the *cheapest*
unlock in the tree. Had that fleet launched on run one, every contestant would
have built against a lie, in parallel, for a day.

One worktree. Buys the whole run.

## Instrument it, do not gate it — the scoreboard is the trade

The real fear underneath "let's be careful" is a fleet burning unwatched. That
fear is legitimate and **permission is the wrong remedy** — it costs you the
door's entire value to buy visibility you can get for less. The remedy is a
live board. An autonomous loop is **watched**, not asked.

The loop must emit, per round: **the bar, the current number, the delta, and
what moved.** Monotonic history, on disk, in the repo — so *plateau is computed,
never felt*, and so the human can glance at progress mid-run without stopping
it. The board is the same honesty contract the hub holds
(`../arbiters/gardener.md`): computed only, provenance visible, freshness
visible. A hand-patched number here is a corrupted instrument steering an
unsupervised fleet.

**Build the board before the first round.** A gauntlet with no live scoreboard
is exactly the gauntlet you would have to gate — not because autonomy is
dangerous, but because you'd have no other way to see it.

## The exclusion ledger — without it the bar is unreachable and the plateau is fake

Not everything in the reference's domain is *in scope* for parity, and this is
the failure that quietly kills long runs. A Zig-only test has no JavaScript
parity. A platform intrinsic has no analogue. A behavior the reference has and
we deliberately refuse is not a gap — it is a decision.

Declare them. **An in-tree, version-controlled ledger, one line per exclusion
with a reason.** Without it:

- the bar can never be met, so **exit-on-bar never fires** and a finished run
  reads as a failing one;
- the plateau reads as defeat when it is actually **completion**;
- and every round re-derives the same phantom gap and spends a contestant on it.

**This is where the human judgment goes at rung 1 — and it is the whole reason
the diffs don't need it.** An exclusion is a *judgment* ("this is out of
scope"), and judgment belongs to the walk. A diff against an oracle is a *fact*,
and facts don't need arbiters. So the gate moves rather than disappears: you
ratify the **ledger**, not the rounds. A contestant may *propose* an exclusion,
never enact one — an unratified exclusion is conformance fraud with better
paperwork, the parity-run form of editing the test to match the compiler.

## Exit conditions — four, and three of them are good news

- **The bar is met.** On rung 1 this is a real, honest finish. Take the win.
- **Plateau** — the closer stopped moving across N rounds. The calibration pull
  gave you the first measurement, so this is computable from round two onward.
- **Budget exhausted.** Declared before the first spawn, in rounds or in wall
  time. A gauntlet without a declared budget is not autonomous, it is unbounded.
- **The ledger grew faster than the score.** A run producing mostly *exclusions*
  is a run discovering that the bar itself was wrong. That is a finding worth
  more than the parity was — stop and take it to the walk.

A run that ends on plateau or budget comes home as a **Frontier**
(`../arbiters/contest.md`) and it is first-class: *"here is the bar, here is
ours, here is the gap I could not close"* — with a number nobody can argue with.

## What comes back to the walk

**The run, not the rounds.** One judgment at the end, not N along the way:

- the final board, re-run by you on the merged tree (`../arbiters/judge.md` —
  the contestant's claims are hypothesis, always);
- the ledger diff, with each proposed exclusion ratified or rejected;
- the frontier: what plateaued, and the closer's own reading of why;
- the full sweep, cold, on the merged tree — the Arbiter's gate is unchanged.

And the standing guard, which no rung relaxes: **the bar is a measure, not a
telos.** A diff that reached parity while drifting from the scene loses to one
that missed and held it. Beat someone else's product as your only standard and
you have built someone else's product.

## The replay is the judge — send the complainant back

When the bar came from a **catalog entry** rather than an external system, there is
a closer available that costs nothing and is better than any review: **re-run the
exact instrument whose complaint motivated the work, and see whether it retracts.**

Not a fresh reviewer, and not you reading the diff again. The specific arrival,
walker or resident that reported the gap, replayed against the changed surface. It
carries its own pitch/probe cross-check, so it does not offer an opinion about
whether the fix is good — its assertions either still hold or they do not, and a
claim that has become false takes the entry red on its own. There is no LLM in that
verdict.

**What it catches that nothing else does: your own defects.** A reviewer reads what
you wrote. The complainant re-measures the world, and it is looking straight at the
thing you just touched, with a motive that makes your mistake load-bearing. Encoded
2026-08-06 after a build night in which four separate defects — a key id that
collided across deployments, a verification key published where no verifier would
look, a fix applied to new doors and never retrofitted to the ones the complaint
named, and a cleaning tool whose prefix list was a guess — were each found by the
very agent whose gap the work was answering. **Zero of the four were found by the
arbiter who wrote them.**

Three disciplines make the replay honest:

- **Never ask for a conversion.** A complainant told the work is done will find a
  way to be pleased. Brief it to keep its verdict wherever it honestly lands, and
  say plainly that a still-NO with a sharper reason is the better result. Most of
  them should not flip; the fix closes one objection, not the motive.
- **Retract in the instrument's own voice.** The stale claim is corrected inside the
  entry, by the entry, naming what it said before. Deleting it quietly loses the
  evidence that the surface moved.
- **Turn the retracted half into a GUARD.** The claim that demanded the capability
  becomes the claim that fires if it regresses. That is the whole compounding move:
  a catalog that accrues defences instead of grievances, one per fix.

A bundled complaint splits rather than restating — half of it is usually what got
fixed, and a claim that can only be all-true or all-false will keep breaking on the
answered half.

## Gauntlet or challenge? — depth against the world, breadth against yourself

The two doors are siblings and they patch each other's blind spot. They are
never blended: a brief does not get a `bar:` field, and a gauntlet does not grow
a catalog.

| | **Gauntlet** | **Challenge** |
|---|---|---|
| loop | **depth**, within one run | **breadth**, across runs |
| ground truth | the **world** — an external reference | its **own catalog** — diverge from what's there |
| exit | beating the bar, or plateau | your taste-gate |
| metric | closing the gap | **variance** |
| failure mode | converging on someone else's product | a wide, mediocre catalog near nothing |

And neither is for **convergent one-answer work** — one bug, one keystone. That
is the ordinary walk: Scout → Commission → Contest.

## Running the day

1. **Name the reference and the rung** at the door. Admissible, or there is no
   gauntlet today.
2. **Declare the budget and open the ledger** — both before the first spawn.
3. **Calibrate**: one pull, closer self-certifies, honesty fraction small enough
   to trust. Fix the closer until it is; this is upstream-first (tenet 8), not a
   delay.
4. **Build the board**, then let it run at the rung's leash.
5. **Glance, don't gate.** The board is readable mid-run by design.
6. **Judge the run on the walk** — board verified, ledger ratified, frontier
   read, full sweep cold on the merged tree.
7. **Gardener + handoff** as any other run. A closer that earned its keep is a
   promotion candidate: a recurring parity check graduates into a standing wall
   (`../arbiters/gardener.md`).
