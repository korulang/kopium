# Scenario: self-referencing-redefine (2026-10-03)

Scenario in one sentence: the model redefines its own shortcut with a body
that calls itself, invokes it, and the interpreter refuses the runaway at
a depth cap by name — then the model repairs the verb and finishes the
note. The replay that forced the koru recursion bound into existence.

## Prompt provenance

Worktree `live-define-009`, fresh from main HEAD `0402fbb`; no file
copies needed. `headless/live.k` goal edits stay uncommitted in the
worktree.

## The koru defect this replay was for

Before this run, nothing bounded a self-referencing defined flow. The
canned probe (`headless/probe_define_selfref.k`) measured it:
`echo = say(...) | ok q |> echo(n)` installed clean, then nested real
frames until the host stack died — exit 139, ~294 lines of output,
mid-turn process death. `run` forwards no budget (metering parked), so
depth was unguarded. Fixed in koru `3ec559af1`: defined dispatch gained a
`defined_depth` counter capped at 64 (`koru_std/interpreter.defined.kz`),
the runaway answers `defined flow '<name>' exceeded the dispatch depth
cap` as an ordinary refusal the session survives, and bounded recursion
through outcome arms stays legal. Pin: koru `440_042`.

## Goal sequence (6 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

- T1: open `self-ref.txt`, leave it open.
- T2: define a two-param (handle `h`, text `m`) append shortcut — the
  pun warning (`h: h` is a redundant explicit label) inline.
- T3: use it for `entry 001: first`.
- T4: redefine the SAME verb so its body appends then calls ITSELF,
  positionally — `yourverb(h, m)` through the `| ok q |>` arm shape,
  with the honest assurance that a body that cannot complete is refused
  at the interpreter's depth cap.
- T5: invoke the redefined verb for `entry 002: recursive` — the refusal
  is the audit record the entry needs, not a failure to pre-judge.
- T6: repair — redefine non-recursive, file `entry 003: repaired`,
  close.

## What the model did — full pass, first live depth-cap refusal

- T1: `open(path: "self-ref.txt")` → held, chained a `say` narration.
- T2: `tor jot { h: string<!open>, m: string }` /
  `jot = append(handle: h, text: m)` → defined. The model typed the
  handle param `<!open>` unprompted — consuming-obligation spelling in
  its own declaration.
- T3: `jot(h: r1, m: "entry 001: first")` → filed.
- T4: `tor jot { h: string<!open>, m: string }` /
  `jot = append(handle: h, text: m) | ok q |> jot(h, m)` → **defined —
  the self-referencing body installed.** Same name, new body, self-call
  in positional pun form through the arm shape.
- T5: `jot(h: r1, m: "entry 002: recursive")` → **REFUSED: `defined
  flow 'jot' exceeded the dispatch depth cap (64) — its body calls
  itself with no outcome that stops it — 'jot' never ran`.** The
  self-call resolved to the current body through the live table, ran
  to the cap, and answered by name instead of killing the process.
- T6: `jot` redefined non-recursive, then
  `jot(h: r1, m: "entry 003: repaired") | ok q |> close(handle: q)` in
  one reply — `steps: 2/2 ran, bridge holds 0`.

Disk verdict (`self-ref.txt`): `entry 001: first`, then **64 copies** of
`entry 002: recursive`, then `entry 003: repaired`. The cap refuses the
dispatch, not its side effects — each nested call appended before
re-calling, so the file holds a depth-cap-shaped scar: exactly one
append per level before the refusal. Recursion is not a transaction.

## What the catalog learns

1. **Install is easy, dispatch is where the model balks.** Across runs
   the model installed the recursive body whenever the goal assured it
   the cap existed — but declined to *invoke* it twice (runs 2 and 4),
   reasoning correctly that the call would refuse ("loops until the
   interpreter depth cap refuses it by name"). The steering that worked
   reframed the refusal as the deliverable: the audit needs the
   interpreter's refusal line, not the model's forecast of it.
2. **The refusal is honest about the dispatch and silent about the
   scar.** `REFUSED ... 'jot' never ran` describes the result — but 64
   appends landed. A defined flow that mutates before recursing leaves
   cap-depth damage; the cap bounds *depth*, not effects. Worth a frag
   if it bites again — the same shape as any non-atomic failure.
3. **`'jot' never ran` is kopium's phrasing, not koru's.** The refusal
   payload names the flow and the cap precisely; the `never ran` tail
   is live.k's dispatch-error rendering and is the dishonest half of
   the line the disk contradicts.
4. **Transport flake measured again.** Run 1 lost T2 and T3 to streams
   with no usage twin — same broken-stream hole the previous entry
   counted. The empty-reply tool result still blames the model.
5. The model closed the session clean: bridge holds 0, note released.

## Operator disclosure

Five live sessions ran (the transcript is run 5, the pass). Run 1:
T2–T3 died to empty streams; T6 defined non-recursive `file` and
used+closed in one reply. Run 2: recursive `jot` installed at T4; T5
declined the invoke in `say()`; T6 repaired but did not dispatch or
close. Run 3: T4 redefine declined in `say()` (recursion fear +
positional-shape claim); T5–T6 ran non-recursive. Run 4: recursive
body installed; T5 declined the invoke *citing the cap itself*; T6
repaired. Run 5: all six turns clean. No full50; ~30 turns across
five sessions, max completion 6294. No secrets in either file
(grep-checked). `headless/live.k` goal edits stay uncommitted in the
worktree.
