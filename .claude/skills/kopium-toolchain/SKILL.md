# kopium-toolchain — the existing-scene instrument

*MAP, not a copy. Points at the tools; duplicates nothing. Fast clock:
read this, then the live repo. For the slow clock (where we're going),
read `/SCENE.md`.*

## What this is

KOPIUM — an agent whose only tool is a Koru interpreter. Vocabulary-parametric
runtime: a `register` block derives prompt, wire grammar, enforcement, growth.
Governing stance: `KOPIUM_RUNTIME.md`. R1 experiment measured 2026-09-05
(`session.k`: define → vocabulary → dispatch under possession). Define-time
scope filter pinned at 440_018 on `wip-define-scope-filter`. Current goal:
**R3 flow-compiler**; remaining R1 rung is define-time obligation honesty.

## Build / run

- Toolchain: `koruc` from `/Users/larsde/src/koru` (`zig build` →
  `zig-out/bin/koruc`, symlinked on PATH). Libraries at
  `/Users/larsde/src/koru-libs` (relative paths in each `koru.json` assume
  this layout).
- Canned bridge demo (zero tokens, deterministic):
  `cd headless && koruc session.k && ./a.out`
- Live agent (spends model tokens — ask before benchmarking):
  `cd headless && koruc live.k && ./a.out`. Needs
  `~/.pi/agent/auth.json` with an openrouter key. Default target
  `meta/muse-spark-1.3-contributor`, temp 0, budget 100k (testing) —
  all tor parameters at the `converse(model:)` call site.
- Probes (zero tokens): `koruc probe_<name>.k && ./a.out`.
- World-model regime: `wm/run.sh` adapter (refusal gate + wire-law probe,
  ~12s) + `wm/faucet.sh` NATS leg (publishes adapter signals to
  `world.signal.kopium.*`, warn-and-drop). `wm run --occupied`, `wm tree`,
  `wm faucets`. Nothing is declared in `signals/` without a bus faucet.
- Challenges: `challenges/<slug>/CHALLENGE.md` + catalog beside it
  (fleet registry finds them by frontmatter). Standing: `model-sweep`
  (wire transcripts), `harness-join` (grows `bench/harness-check.py`).
- Mock/airline bench (spends model tokens — ask first):
  `python3 bench/run_mock.py`, `run_airline.py`, `run_mock_traj.py`
  (per-task trajectories under `bench/results/trajectories/`).
  Gate is a long-lived process (`GateSession`).

## Gates (walls — run, don't argue)

- `./possession-check.sh [N]` — N forged closes refused pre-proc, 2 real
  holds accepted. Exit code IS the verdict.
- `./refusal-check.sh` — canned turn 3 REFUSED, turn 6 DENIED, hang-up
  discharges. Falsified before trusted.
- `python3 bench/harness-check.py` — joins that make the τ³ path and
  the long-running bridge the same machine. Rebuilds from source;
  exit code IS the verdict.
- Pre-push (`.githooks/pre-push`, runs both gates).
- Commit-msg membrane gate (`.githooks/commit-msg`): every commit message
  carries a `## World Model` section or it is rejected. Acknowledge
  explicitly when nothing belief-worthy changed.

## Hooks layout (will bite)

- `core.hooksPath` is `.githooks` — git NEVER looks at `.git/hooks/`.
  The seed installer put the membrane gate there; live copies are in
  `.githooks/` (commit-msg, post-commit + .cjs). Keep both in step or,
  better, fix the installer to respect hooksPath.

## Source of truth

Runnable artifacts win over prose, always (developer's standing order):
the bridge's behavior, the gates, the koru `440_*` pins. Docs are
scaffolding — prune the moment running code carries them.

## Standards (must-read for every subagent)

- `KOPIUM_RUNTIME.md` — the stance (derived-never-authored, terminating
  vocabularies, capability/authority split).
- The koru compiler is the product: toolchain gaps get a `wired/holes/`
  repro + a koru-side pin, NEVER an app-side dodge.
- Commit style: lowercase `area: short description`.
- Off-limits: `--no-verify`, force-push, secrets, unapproved model spend.

## Things that will bite you

- `build.zig.zon` `.fingerprint` rewrites on every FULL backend build
  (cached builds don't touch it). Revert before committing; the fix is
  koru-side (hole 5).
- `a.out` binaries: root `.gitignore` covers `a.out` and `a.out.*`.
  `rm -f a.out` after runs anyway.
- Phantoms need the module qualifier in tor params:
  `*koru/yyjson:Doc<koru/yyjson:open>`, never bare `<open>`.
- Tor call labels: single-arg calls need the explicit label
  (`clean(raw: "...")`); watch PARSE005 hints.
- Reasoning models burn budget invisibly: `finish_reason: length` +
  empty delta, zero content. Budget = worst-case thought + utterance.
  `[usage]`/`[wire-note]` lines in `live.k` output show the split.
- SSE terminal usage is observed twice (hole 4)   — don't treat counts as exact until settled.
- `wire:clean` keeps the WHOLE turn; `std/bridge:run` sequences multi-item
  turns and reports one line per step under `?partial` (frag-partial-programs,
  landed 2026-09-10). `extra-lines` is retired.
- `say()` killed the live forgeries: `HandleNotHeld`/`event-denied`
  have no live witness — only canned `session.k` (+ refusal gate).
