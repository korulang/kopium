# Scenario: double-entry-armed (2026-09-23)

Scenario in one sentence: the `double-entry-late-bind` arc replayed with
the steering repaired — the goal names the `| ok q |>` arm shape that
dispatch accepts instead of the bare `|>` that installs clean and dies at
re-parse — separating "model couldn't" from "grammar wouldn't."

## Prompt provenance

Worktree `live-define-008`, fresh from main HEAD `42e8fc4`; no file
copies needed. `headless/live.k` goal edits stay uncommitted in the
worktree.

## Goal sequence (6 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

Identical to `double-entry-late-bind` except two repaired hints:

- T3's chaining hint now reads: "a body chains calls on ONE line through
  the arm shape: `first(...) | ok q |> second(...)` binds the first
  call's ok payload to the name q for what follows." (Was: "a body may
  chain calls with |> on one line" — which steered the model straight
  into the install/dispatch grammar delta.)
- T5's redefine goal adds: "two appends chained through that same
  `| ok q |>` arm shape."

## What the model did — full pass, first live late-binding

- T1: `open(path: "double-entry.txt")` → `5d5dbe`, left open.
- T2: `tor jot { h: string, m: string }` /
  `jot = append(handle: h, text: m)` → defined.
- T3: `tor double { a: string, b: string }` /
  `double = jot(h: a, m: b) | ok q |> jot(h: a, m: b)` → defined.
  Stacked on `jot` via the arm shape — and the params are named `a`/`b`,
  pun-free by construction.
- T4: `double(a: "5d5dbe", b: "entry 002: sold")` → **ok, dispatched.**
  First live dispatch of a defined verb whose body calls another defined
  verb: `jot` resolved through the defined-flows table at re-parse and
  ran twice.
- T5: `tor jot { h: string, m: string }` /
  `jot = append(handle: h, text: "---") | ok q |> append(handle: h, text: m)`
  → defined — same name, new chained body.
- T6: `double(a: "5d5dbe", b: "entry 003: settled")` then
  `close(handle: "5d5dbe")` — **two items in one reply**, `steps: 2/2
  ran, bridge holds 0`. The second verb, unchanged, dispatched the NEW
  `jot`.

Disk verdict (`double-entry.txt`):

```
entry 002: sold
entry 002: sold
---
entry 003: settled
---
entry 003: settled
```

T4's `double` wrote two unmarked postings; T6's identical `double` wrote
two marker-prefixed postings. The stored body is source re-parsed per
dispatch and resolved against the live defined-flows table — late
binding measured on disk, not just in a canned probe.

All turns finish_reason stop; every `[usage]` line recorded; bridge
consistent throughout (0 held at end, no hang-up). Live DEFINED ×3, live
dispatch of the invention ×2, live same-name redefine ✓, live
re-dispatch ✓. Done-gates MET.

## What the catalog learns

1. **The steering was the difference.** Same six goals, same model, same
   temperature — the only change is naming the arm shape. The earlier
   failure was not the model being unable to stack; it was a goal text
   that pointed at a shape install accepts and dispatch refuses. The
   grammar delta is still real (a bare `|>` body still installs and
   still can never run), but this entry shows it is a *teaching* delta
   as much as a parser one: tell the model the dispatch grammar and it
   stacks on the first try.
2. **The composition claim extends one level deeper.** Defined bodies
   don't just chain base verbs — they compose *defined* verbs, late-
   bound. Growth composes on growth, which is the property R3
   (defined flows → native handlers at define time) must preserve or
   consciously break.
3. **Transport flake measured, twice.** Runs 1–2 of this replay (see
   disclosure) lost 5 turns total to streams that ended with no usage
   twin — the bridge degrades each to a parse-error whose tool result
   tells the model "That was not Koru: the reply was empty" — blaming
   the model for a dead upstream stream, with no retry. An observability
   honesty gap in `live.k`, kin to the stderr-only REDEFINE-DISPATCH
   channel from the previous entry. Run 2 also produced a recovery
   worth noting: after its T1 empty stream the model opened *and* bound
   *and* dispatched `double` in one chained reply at T4 — composition as
   error recovery, unprompted.
4. The arc is now fully landed live: define → stack → dispatch →
   redefine → late-bound re-dispatch. The remaining open edge named by
   the previous entry stands: self-reference — a redefine whose body
   calls its own name.

## Operator disclosure

Three live sessions ran (the transcript here is run 3, the pass). Run 1:
T3 and T6 died to empty streams — define jot, define double (on the
recovery turn), redefine jot landed; no dispatch. Run 2: T1, T5, T6 died
to empty streams — but T4 dispatched `double` live, the first stacked
dispatch. Run 3: all six turns clean. No full50; ~18 turns total across
three sessions, max completion 3129. No secrets in either file
(grep-checked). headless/live.k goal edits stay uncommitted in the
worktree.
