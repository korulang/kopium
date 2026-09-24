# SCORECARD — kopium vs the harness shapes

*Read-many, append-often. Every cell is labeled: **measured** (evidence cited,
runnable), **structural** (argument from the architecture, not run), or
**unmeasured** (the honest hole). A structural claim that could be measured is
debt, not a win. Rows append as replays land; a cell that flips from measured
to structural or back is a real event — say so.*

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
| Cost / reliability vs a foreign baseline | **unmeasured** — every number above is arm-vs-arm inside kopium | unmeasured | unmeasured | unmeasured |
| Grammar coherence — one language end to end | **measured, negatively** — install accepts bare `|>` bodies that dispatch refuses (`2026-09-23-double-entry-late-bind`); the claim is a work in progress, honestly | n/a | n/a | n/a |

## What a baseline harness would measure

The one row that turns this from argument into comparison: a thin
function-calling loop over the same model (`meta/muse-spark-1.3-contributor`,
temp 0) with the same six verbs as JSON tools, run against the same task
battery — serial open→append→close, the three-note fan-out, and the
define-a-verb arc (where the honest measured result for the baseline is
`cannot express`). Cost-to-completion, bytes-right reliability, turns-to-done.
~150 lines of Python on `bench/`, reusing the experiment.py harness shape.

## Publishing

The publishable surface exists: `korulang_org` blog (`+page.svx` posts,
`draft:` frontmatter), hyperframes for charts, `pnpm deploy:prod` is the only
publish path (see `status-ceremony`). `all-of-kopium` (draft, 2026-09-06) is
the snapshot post this would succeed — it predates holes 6–9, the wire flip,
composition economics, and the entire live-define catalog.
