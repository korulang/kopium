---
challenge: live-define
kind: generator
status: standing
yields: one hostile define scenario + live transcript
catalog: ./catalog
family: wire
created: 2026-09-07
---

*Walker context: the canned probe (`bench/probe_live_define.py`, wall 15/15)
proves the drive path CAN carry a two-line define. What it never proves is
a model choosing to define live — inventing a verb, using it, redefining
it — under real spend. The `model-sweep` catalog holds one Muse Spark
transcript with pre-define goals; `inventions-accumulate` holds two canned
defines. Neither holds a hostile live define. This generator grows that
shelf: each replay is a new define-forcing goal sequence run against the
live model, with the full transcript as the artifact.*

*Siblings stay independent. `model-sweep` varies the model; this brief fixes
the model and varies the scenario. `harness-join` / `oracle-join` grow wall
cases, canned and keyless; this brief spends (small) and lands transcripts,
never wall cases. It drinks those catalogs as facts on disk; it does not
replay them.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Do not ask which scenario; pick one. Read `./catalog/`
first (and `challenges/model-sweep/catalog/` for the pre-define shape) and
bring a define-forcing goal sequence it hasn't seen. Variance is the metric:
a replay that re-runs an existing scenario's goals is a re-run, not a replay.

A scenario is hostile when the model must GROW to succeed: at least one turn
whose goal can only be met cleanly by defining a verb, a later turn that calls
the invention, and a later turn that redefines it (same name, new body) and
calls again. Canned declarations never touch the wire; every define arrives
through `app/wire:clean` + `std/bridge:run` on the live drive path.

1. Fix the model to `meta/muse-spark-1.3-contributor`, temp `0`, budget
   `100000` at the `converse(model:)` call site. Model is NOT your variant;
   the scenario is. Work in your worktree; do not commit changes to
   `headless/live.k` — the transcript is the artifact, not the goals.
2. Set a 3–6 turn goal sequence at the `converse` call site that forces
   define → use → redefine → use. Keep goals in the notes world (open,
   append, close, say + inventions). Small spend is expected; a full50
   grind is NOT this brief.
3. `cd headless && koruc live.k && ./a.out` — one live session. Capture the
   FULL unedited program output, including `[usage]` lines.
4. Write `catalog/<yyyy-mm-dd>-<scenario-slug>/scenario.md`: the scenario in
   one sentence that can be wrong, the goal sequence, what the model defined
   and redefined. Write `transcript.md` beside it: a header (date, temp,
   budget, define/use/redefine verdict, one-line verdict) plus the FULL
   output. Never include secrets: the bearer must not appear; grep both
   files before you finish.

Done-gates (self-check, all mechanical): it compiles; the live run
terminates with a recorded finish per turn; both files exist; the output
shows a live `DEFINED`, a live dispatch of the invention, and a live
redefine of the same name dispatching again; no secret strings in either
file; you did not run a full50. Taste-gate: the human reads the entry and
learns something the catalog didn't already say — or it is an honest
duplicate and says so.
