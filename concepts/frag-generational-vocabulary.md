---
type: belief
id: frag-generational-vocabulary
provenance: live thread 2026-09-23 — "this was MEANT to be an implementation
  of RLM, where it can recursively improve" — locating the lost leg in code
ts: 2026-09-23
---

# The recursive loop needs heredity — and heredity needs a verdict

Kopium was always meant to be an RLM — the recursively-improving leg. The
pieces were built but never closed into a loop: the model CAN rewrite its
own vocabulary mid-session (measured live: stacking + late binding, catalog
`double-entry-armed`), but `DefinedFlows` is durable *per session* —
allocated at `bridge:create`, destroyed at deinit, serialized to nothing.
Session N+1 inherits nothing. Growth without persistence is not recursion;
it is a series of sessions with good moments.

The loop that makes recursion *improvement* rather than oscillation maps
onto the three evolutionary operators:

- **Variation** — the model itself. Every session invents freely; scenario
  steering steers the mutation operator.
- **Heredity** — the missing piece. Persist the defined-flows table across
  sessions (a vocabulary file per scope, loaded at bridge create) and
  session N's inventions become session N+1's starting genome. One seam,
  koru-side; the derivation machinery (vocab → prompt) already exists, so
  inherited verbs surface in the prompt for free.
- **Selection** — the oracle layer (`frag-oracle-coverage`). Episode
  verdicts score which definitions earned their keep; only definitions
  from passing sessions inherit. A bad verb variant cannot fossilize into
  the genome because it never passed a gate. *This is why measurement and
  recursion are the same work*: the oracle is the fitness function.

The domain that makes all three real is koru-libs: its suite board is a
mechanical oracle over *work that matters* — packages are instruments that
exercise the compiler, so an agent greening the board is the toolchain
improving itself through its own consumer. The genotype is an inspectable
`.kz` vocabulary file you can read, diff, and garden — recursive
self-improvement where the artifact under selection is a program you can
hold.

2026-09-23, the libs scope landed (`headless/libs.kz`) and sharpened one
edge: **heredity has two channels, and the cheaper one was already free.**
A filesystem domain persists its own work — an edit that survives a
session needs no vocabulary seam, and the suite re-measures it every
generation. World-state heredity is the domain's property; only the
*vocabulary* genome waits on the `DefinedFlows` seam. So the workbench
loop (edit → check → test → board) already closes a full generational
cycle over artifacts — the missing seam gates only the agent's own
inventions riding along.

2026-09-25, a third sharpening: **the generator's self-grounding step is a
verb, not an operator habit.** Challenge doctrine says a replayable
generator re-derives "what's missing" from its own catalog each run; here
`queue()` makes the corpus compute that — tests on disk minus cases suite.k
declares — so the frontier is a wire value the model reads, not a task an
operator picks. Selection already lived in `board()`; variation in the
model; heredity (of world-state) in the filesystem. With `queue()` the
fourth leg — *what to work on next* — also lives inside the world, and
the loop `queue → work → board → queue` needs no human between turns.
The remaining human gates are promotion (commit, catalog) and taste, not
task-selection.

Open edges: the vocabulary file's provenance fields (defined-by,
earned-on, use-count); name collisions across generations (redefine
already rules it — last write wins, which is correct); staleness against
scope changes (a persisted verb that calls a renamed event should refuse
loudly, and the refusal taxonomy already has the slot); and whether
promotion is auto (all green-session definitions inherit), taste-gated
(human promotes), or oracle-gated (per-verb episode evidence). The
oracle-gated shape is the interesting one — a verb earns inheritance the
way a test earns a pin.

2026-10-03 — **heredity landed** (koru `e7c50e9ac`, pinned `440_040`):
`create(world: <dir>)` mounts a directory of `*.k` files as the session's
starting vocabulary, and every define that lands writes
`<dir>/<name>.k` — verbatim definition source, one file per flow, so the
genome is a directory of programs you can read, diff, and garden, not a
serialized table. Restore replays the same `installDefine` path a fresh
define takes, so mount is the same mechanism, not a second one. What the
frag got right: "a vocabulary file per scope, loaded at bridge create" —
the seam was exactly that small. What it sharpened: the write path is
`define` itself (one verb, two effects), not agent-level file verbs.
Staleness got teeth by accident — a corrupt genome panics at mount naming
the file, because `-> *Bridge` cannot spell a refusal arm. The generational
claim is now testable rather than designed: session N+1 CAN inherit. What
still separates inheritance from *improvement* is the selection edge
above — promotion has no oracle yet.
2026-10-03 — **the seam woke** (`heredity.k` headless demo + `KOPIUM_WORLD`
on the bench path): inheritance is no longer pinned-but-dormant — real
sessions mount worlds. Two demonstrations, one receipt each: `heredity.k`
runs session A doing open/append/close by hand, defining `log-line` as the
composite, closing; session B mounts the same dir and dispatches `log-line`
on turn one — the composite body chains verbs through arm-bound results
(`| ok h |>`), which is the grammar a defined flow's body actually speaks.
On the bench path, `corpus-replay` with `KOPIUM_WORLD` persisted
`find-user` and the next process's `vocabulary()` — the prompt's own
source — listed it. The frag's next edge is unchanged and now load-bearing:
promotion still has no oracle, so fossilization is live.
