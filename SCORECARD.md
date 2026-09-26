# SCORECARD — kopium vs the harness shapes

*Read-many, append-often. Every cell is labeled: **measured** (evidence cited,
runnable), **structural** (argument from the architecture, not run), or
**unmeasured** (the honest hole). A structural claim that could be measured is
debt, not a win. Rows append as replays land; a cell that flips from measured
to structural or back is a real event — say so.*

## The gate — stated 2026-09-25

**Unless a shared-axis measurement shows fruit, this project is not where
the time goes.** That is the agreed frame, and it is falsifiable by
construction:

- The refresh that must happen: `bench/run_compare.py` on current main —
  same tau2 airline tasks, same model, both arms, trajectories + reasoning
  captured this time.
- What counts as fruit: koru reward moves decisively off the stale 10/28
  toward the stock arm's 25/28, *attributable* to the wire flip and the
  landed holes — i.e., cap-outs and serial-dependence failures shrink in
  the trajectory census, not just the reward digit.
- What the other outcome means: a refreshed ~10/28 on current main says
  composition didn't move the shared axis — then kopium's remaining claim
  is category-level (capability grammar, growth, enforcement the others
  can't express), and that claim does not pay rent on a benchmark it
  wasn't designed for. Continued spend then needs a different
  justification than "competes with pi/omp" — say so plainly or stop.

The gap is named: **parity-evidence.** Everything below the line is the
case for; the gate is the case for continuing at all.

### Verdict — measured 2026-09-26: the gate failed

Refresh (refresh1 + refresh1b shards, aborted at 14 scored tasks once the
direction was unambiguous): **koru 7/14 vs stock 12/14** — tracking the
stale 10/28 shape, nowhere near the 25/28 bar. The wire flip did not move
the shared axis. The 4 run_compare shards were killed mid-flight; rows
already flushed live in `results/compare_refresh1b_sh*.csv`.

Two confounds on the measurement itself, both now named:

- **Koru token/cost columns in all prior compare CSVs were phantom.**
  `KopiumAgent` emitted `AssistantMessage`s with `usage=None`; tau2's
  `get_token_usage`/`get_cost` therefore counted only the shared user
  simulator. The "~6x koru efficiency" those cells implied never existed.
  Fixed in `f0ba70b` (usage+cost summed across the retry loop onto the
  returned message); all pre-fix token/cost cells on this page read as
  **unmeasured**.
- **Provider weather corrupted several koru rows** (stall-storms mid-task;
  task 4 capped at 2.7h, task 1 lost to ~50min dead air, later re-flown
  green by shard 1). The gap survives the correction — clean tasks
  (12, 14, 15, 24) went 0.0 where stock rows are 1.0.

Per the gate's own text: the remaining claim is **category-level**
(capability grammar, possession lifecycle, live vocabulary growth — the
measured column below), and benchmark competitiveness is not the
justification for further tau2 spend.

The comparison set:

- **function-calling** — OpenAI/Anthropic-style tool calls: JSON schema
  describes, host code enforces, model emits typed calls.
- **MCP** — tool servers behind a protocol; model picks from a published
  tool list; semantics live in the server.
- **code-interpreter** — model writes and runs a program (Python, shell)
  against a sandbox; the world is whatever the runtime can reach.
- **kopium** — the register block derives grammar, prompt, enforcement,
  growth; the model's reply is a wire fragment dispatched by the bridge.

## The dimensions

| Dimension | kopium | function-calling | MCP | code-interpreter |
|---|---|---|---|---|
| Capability as grammar — a forbidden utterance refuses at parse | **measured** — refusal gate: 900/900 forged closes refused; a handle nobody minted dies at the pool (`bench/` refusal pins, pre-push gate) | structural — schema validates shape, not permission; "don't call X" is prompt prose | structural — server may refuse at runtime; the call itself was legal | structural — sandbox refuses effects, not utterances |
| In-turn data dependence — a reply threads a just-minted handle through a chain | **measured** — `open \| ok h \|> append(handle: h)` runs live; `steps: 2/2 ran`; T4 of `double-entry-armed` composed open→bind→dispatch in one reply | structural — parallel calls only; no intra-reply dependence in the API shape | structural — same limit, one level removed | measured-adjacent — a program can thread anything, but nothing declares what's legal |
| Vocabulary growth in the enforced language | **measured** — live-define catalog: 6 entries; define→use→redefine→late-bind full arc landed live (`2026-09-23-double-entry-armed`); defined verbs stack, late-bind | structural — tools array is request-scoped host data; swappable between turns, but the body lives in host code, not the conversation's language | structural — servers publish tools; the model cannot author them | structural — can define functions freely; nothing enforces them against a declared world |
| Possession lifecycle — opaque mints, forged-handle refusal, auto-discharge at hang-up | **measured** — `<open!>`/`<!open>` edges declared per event; forged literals refused; hang-up discharges held resources (refusal gate, every live transcript's tail) | structural — handles are values; possession is host bookkeeping if it exists at all | structural — same | structural — same |
| Typed refusals that teach | **measured** — `unhandled-branch` hand-back explained back by the model the next turn (2026-09-08 witness); per-step `?partial` reports; parse-error vs event-denied vs validation-error vs exhausted | structural — an error string in the tool result; typing is convention | structural — same | structural — a traceback; typed only by accident |
| Parametricity — one declaration → working agent for N domains | **measured** — three vocabularies from register blocks alone: notes, ledger, calc; derived prompt + wall + growth carried free (`probe_calc.k` green across ten turns) | structural — each tool set is a bespoke schema + host code | structural — each server is bespoke | structural — no declaration exists |
| Composition economics | **measured** — serial chains ~3× cost tax; independent fan-out ~2.6× cheaper, ~5× faster to first bytes (n=10–15/arm, `bench/experiment.py` rounds 3–4) | unmeasured | unmeasured | unmeasured |
| Cost / reliability vs a foreign baseline | **measured, stale, and losing** — tau2 airline head-to-head vs stock LLMAgent, same model/tasks, Aug 15–16 (`bench/results/compare_full50_taught.csv`): reward **10/28 koru vs 25/28 stock**; koru spent 5.8× fewer tokens and 3.5× less cost, ran 2.3× slower wall. **2026-09-26 refresh-in-progress** (`compare_smoke_r.csv`): post-fix smoke tasks 1+2 both **koru 1.0 / stock 1.0** — koru in 8+10 calls at ~8× fewer prompt tokens and ~5× less cost, task 2 at wall parity (161s vs 171s); **task 10 koru 1.0 / stock 1.0** — 11 calls, faster (248s vs 388s), 18× cheaper (`compare_smoke_s.csv`). The month's loss was transport + memory poisoning, not the wire. n=3 smoke — the full 28-task run is still owed | — (it was the stock arm) | n/a | n/a |
| Grammar coherence — one language end to end | **measured, negatively** — install accepts bare `|>` bodies that dispatch refuses (`2026-09-23-double-entry-late-bind`); the claim is a work in progress, honestly | n/a | n/a | n/a |

## What the baseline already measures — and what it still can't see

The foreign baseline EXISTS: `bench/run_compare.py` runs kopium's gate and
the stock `LLMAgent` (JSON-schema tools) on the same tau2 airline tasks,
same model, graded by the benchmark's own reward + db-check oracle. It is
the strongest kind of oracle this repo holds — an oracle that can see us
lose, and did (10/28 vs 25/28). Two honest caveats: it is a month stale,
and it measures the *wire agent* against airline tools, not the growth
machine against a declared world — the arc where kopium's difference is
the point has no foreign baseline and can't have one (the baseline can't
express the task).

The live-run layer is where the oracle gap actually lives: challenge
done-gates are mechanical in spec but eyeballed in practice; the disk
verdict is `cat` + judgment; a dead upstream stream lands in the
transcript as "the model did not emit Koru" — a mislabeled failure no
gate can distinguish from real silence; and nothing checks whether what
the model *says* is true (the `HandleNotHeld` confabulation was caught
by a human reading, not a checker). A `live-check.py` that eats a
transcript and emits the verdict — finish per turn, DEFINED/dispatch/
redefine lines, secrets absent, resource balance zero, model-cited
refusal names checked against the taxonomy — converts all of that from
reading into an exit code.

## Publishing

The publishable surface exists: `korulang_org` blog (`+page.svx` posts,
`draft:` frontmatter), hyperframes for charts, `pnpm deploy:prod` is the only
publish path (see `status-ceremony`). `all-of-kopium` (draft, 2026-09-06) is
the snapshot post this would succeed — it predates holes 6–9, the wire flip,
composition economics, and the entire live-define catalog.
