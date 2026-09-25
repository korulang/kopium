---
challenge: libs-workbench
kind: generator
status: standing
yields: one live workbench session + suite board delta + transcript
catalog: ./catalog
family: workbench
created: 2026-09-23
---

*Walker context: notes/ledger/calc proved parametricity on toy worlds —
small enough that "did it append" was the whole oracle. This generator puts
the agent against the toolchain's own corpus: the work surface is
koru-libs, the oracle is `koruc suite test` — a board that exists, tracks
green→red history itself, and cannot be argued with. This is the recursion
the project was built for: the agent improving the instrument it speaks
through. Every package greened is a compiler-exercise that persists in the
repo; every verb the model earns is vocabulary a successor session can
inherit.*

*The task queue is self-generating: suite.k currently cases ~3 of 24
packages, and ~41 bare `~proc` sites (curl 13, pq 8, docker 8, ai 5, gzip
7) still spell the pre-KORU110 form that refuses to compile. Every red row
and every uncased package is a task the board can grade without a judge.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Read `./catalog/` first (and `challenges/live-define/catalog/`
for the live-run conventions). A replay re-running a cataloged task is a
re-run, not a replay.

The world is `headless/libs.kz` — the workbench scope (BUILD IT FIRST if it
doesn't exist — that is canned infra work you do yourself, not model work;
record it under operator disclosure). The verbs, all derivable from the
register block per the standing rule:

- `read(path)`, `edit(path, old, new)`, `write(path, text)` — file verbs
  over the koru-libs tree (reuse the notes.kz proc shapes; paths are
  absolute or repo-relative).
- `check(path) | ok | error msg` — shells `koruc --check`; the fast gate.
- `test(path) | pass | fail report` — shells `koruc run <file>`; the
  per-case oracle.
- `board() -> string` — shells `koruc suite test`; the whole board.
- `say(text)` — the voice, as always.

A task is real when the suite grades it without a judge:

- **Coverage gap** — an uncased package gets a case (smoke minimum: it
  compiles and exercises the public entry).
- **Red repair** — a failing case goes green without the test weakening.
- **Idiom migration** — bare `~proc` → `~proc ...|zig` under KORU110.

1. Model: `meta/muse-spark-1.3-contributor`, temp 0, budget 100000. Work in
   worktrees; **model-made edits to koru-libs are never committed by the
   run** — the diff is reviewed by the human, the transcript is the
   artifact.
2. Goal sequence: orient (read the board), name the task, work it, verify
   with `test`/`board`, close out. 4–10 turns. Growth stays legal — the
   model may define workbench verbs it needs.
3. `cd headless && koruc live.k && ./a.out` — one session, full output
   including `[usage]` lines.
4. `catalog/<yyyy-mm-dd>-<slug>/scenario.md`: the task in one sentence,
   goals, what the model did, the suite delta verbatim. `transcript.md`
   beside it: full unedited output. Grep both for secrets.

Done-gates (mechanical): run terminates with a recorded finish per turn;
the suite delta shows the named case red→green or a new case green, with
ZERO unrelated regressions; defined verbs that ran are listed; no secrets;
no full50. Taste-gate: a real package's board got better — not a toy task
dressed as one.

## The heredity leg (pending — not a gate yet)

DefinedFlows is session-scoped by construction: `bridge.kz` allocates the
table at create and destroys it at deinit; every session starts with the
seed vocabulary. The generational loop this challenge is *for* — session
N's earned verbs becoming session N+1's starting vocabulary, gated on
green verdicts — needs one persistence seam koru-side before it can be
gated in the done-criteria. Until then, verb growth inside a session is
recorded in scenario.md but dies with the process.
