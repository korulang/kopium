---
type: belief
id: frag-event-arms-first-match
provenance: headed.k stall-watchdog debugging, 2026-09-11 — read in output_emitted.zig
ts: 2026-09-11
---

# `!` arms under an event join are first-match — a looser guard shadows every later arm

Multiple `! tick` (or `! key`, `! draw`) arms under one join do NOT all
fire. The emitted handler evaluates the guards in source order and each
arm's block ends in `return` — the first arm whose `when` passes owns the
event. A later arm whose guard overlaps is dead code that compiles clean.

Proven by accident: the headed.k stall watchdog (`ui.live == 1 and
ui.stall > 3750`) sat after the pump arm (`ui.live == 1`) and never ran —
every live tick was swallowed by the earlier guard. The same shadowing is
why `ui.retire` must be raised by the `! finished` arm itself: a
`! tick _ when ui.retire == 1` arm placed after `when ui.live == 1` only
gets ticks once live has already cleared.

Corollary design rule: order arms most-specific-first, and treat two
arms that must interleave on the same event as one arm with internal
branches. Flag pairs that are both true (live+retire after a finished
transfer) need the *earlier* arm to advance the state so the later one
can ever see a tick.

Open: whether first-match is the intended language law or an emission
accident is unruled — a koru regression pin (two overlapping `!` arms,
assert only the first ran) would settle it. File under candidate pins.

2026-09-14: first-match is no longer compiled-only folklore. `|` wire arms
carried the same shape the other direction — `when` parsed into
`cont.condition` and the bridge's `selectArm` ignored it entirely, so a
false guard *fired* (bridge-mirror row 6). Koru `e132cf991` made the
interpreter mirror the compiled if/else-if/else lowering: guards judged
in source order against the arm's own binding, first truthy wins,
unguarded is the else, unjudgeable is a named dispatch-error
(`GuardUnjudgable`), pinned by `440_024`. Both arm syntaxes now share the
law: order is semantics, and a guard is a judgment — never decoration.

2026-09-17: first-match's consequence is now enforced, not just observable.
The compiled side refused dead arms all along (SHAPE002); the interpreted
side silently ran first-match and reported `result` — the gap behind the
queued "discharged-handle defect" (`open | ok h |> append | ok h2 |>
close(h2)`: the close sat in a never-firing sibling arm, the pool kept the
handle, a later turn re-appended through it). Koru `a01abb341` mirrors
`firstDuplicateSibling` into `validateFlow` — a second unguarded
same-branch arm is `validation-error` teaching the indent spelling — pinned
by `440_027`. The frag's open question is fully settled: order is law on
both surfaces, and a dead arm is a refusal, not a no-op.
