# Wire gap analysis — agent surface vs Koru semantics

Commissioned 2026-11-15. Purpose: every contract/guide/seed claim about the
wire should trace to a verified Koru semantic, not an assumption. Burned
cells so far (`say|>`, void-step piping, residue binding, guide timing) were
all filled by assumption. This matrix is the audit checklist for the Fable
tune-up: interpreter audit (does the bridge *enforce* what we claim?) and
teaching-surface audit (does the prose match the verified column?) both
hang off it.

Status vocabulary: **verified** (probe or receipt), **asserted** (contract/
guide claims it, no probe), **assumed** (untested), **disputed** (evidence
conflicts).

## The matrix

| # | Construct | Wire shape | Claimed semantics | Status | Evidence / next probe |
|---|-----------|-----------|-------------------|--------|----------------------|
| 1 | say, standalone | `say(text: "...")` | emit-only, void, reaches user | verified | gate_probe cases; receipts |
| 2 | say receiving pipe | `call \| found u |> say(text: "{{u.x}}")` | canonical end-of-pipeline step | verified | gate_probe; every run |
| 3 | say with trailing pipe | `say(text: "...") \|>` | **accepted (Lars 2026-11-15): a partial program**, runs the say. Was misparsed as `unknown field '(text:) \|>'` | verified | koru `9f527faea`, pin 440_062; probe I2 `say "Hello"` → OK |
| 4 | say mid-pipe | `prev |> say(...) \|> next` | **REOPENED + FIXED 2026-11-15: LEGAL.** say/note are void tors; a bare `\|>` after a void tor sequences — the language's backbone, the spelling compiled harnesses use (440_050 `\|> step(...) \|> step(...)`). The earlier ILLEGAL verdict measured a bridge parser gap, not the language | verified | koru `9f527faea`, pin 440_062; probe I1 `say a` → `say b` → OK, F1 `note \|> say` → `say "b"` OK |
| 5 | `\|>` after a call | does `\|>` pipe data or sequence? | **sequences, never carries data.** After a void tor it chains; after an outcome tor the bare pipe names no outcome, so the result falls to the lenient `unhandled-branch` hand-back (deferred, not refused). Data moves only through a named arm, bound for the rest of the turn | verified | koru `9f527faea`; probe A/I3 → `call` + HALT unhandled-branch; cases B–E (`bench/probe_pipe_semantics.py`) |
| 6 | arm on a void tor | `say(...) \| ok x \|>`, `\| ok \|>`, `\| ok _ \|>` | **shape bug (Lars 2026-11-15): refused pre-dispatch** — a void tor issues no outcome. `-> T` tors keep their synthetic `ok` | verified | koru `b9671ab00` + `9f527faea`, pin 440_061; probe F2 `ERROR 'say' is void — it issues no outcome, so '\| ok x \|>' has nothing to arm; chain the next call with a bare \|>` |
| 7 | note | `note(text: "...")` | emit-only, observer lane, void | verified | receipts; `observer:` history msgs |
| 8 | residue | bare prose / unparseable | binds rN, reaches nobody, reasoning only | verified | receipts; REJECT verdicts |
| 9 | multi-item turn | newline-separated items, indent continuation | items run in order; indent = pipeline continuation | partially verified | resp_*.txt shapes; needs pipe-semantics pin |
| 10 | labeled args | `verb(field: value)` | required; positional rejected | verified | PARSE006 errors; gate_probe |
| 11 | phantom/binding args | `reservation: r1` vs literal | binding name required for `<type>` phantoms | verified | dispatch-errors teach it; receipts |
| 12 | branch arms | `\| found r \|>`, `\| error e \|>` | arm expected outcome; error = transport | verified | callsteps armed[] fields |
| 13 | hold→confirm custody | `hold` mints `held!`, `confirm`/`release` consume | obligation lifecycle | partially verified | clean-session test did cancel/say; hold chain unprobed end-to-end |
| 14 | select chain | search→found→select→chosen | chosen required by update/hold | asserted | the contract recipe that taught it was removed with cell #21; never observed firing in receipts |
| 15 | guide timing | `std/guide:add` fires on dispatch/resolution | post-dispatch only — cannot teach pre-dispatch refusals | verified (timing) / unmeasured (refusal coverage) | built mechanism is `frag-guides-fire-at-dispatch` (koru `8c148bdda`): renders into `RunError.trace`, `unhandled-branch.guides`, step reports. Whether parse/validation refusals produce a dispatch record a guide can key on: unprobed |
| 16 | watch identical-call | repeated call+result → error branch | WMFX no-op signal | verified | `unhandled-branch: error` in receipts |
| 17 | introspection verbs | vocabulary/grammar/state/bind/note/abandon (the `host_verbs` table, `bridge.wiregate.kz`; `contract` removed — cell #21) | host verbs, always callable | asserted | bind used by gate_session; others unprobed this session |
| 18 | define | `define name { ... }` | session invention joins vocabulary | asserted | probe_session_mock covers mock scope |
| 19 | `expr: Expression` args | `tor f { expr: Expression }` | exists in koru_std (array sort `[norun|expand]`, cell, channel) | assumed-for-emit | would `say { expr: Expression }` legalize `say("...")`? unprobed |
| 20 | `@"path"` literal | `f(@"file.md")` | NOT Koru — passes frontend, dies in backend | verified-hole | koru red test `100_089_at_string_literal_passes_parser` (2183477d0) |
| 21 | contract() verb | `contract()` → whole doctrine blob | **REMOVED both surfaces.** native_protocol.k `46fc178`; airline_tools.k twin + gen_airline.kz emission removed (regenerated, 94 deletions). Tors already self-describe via per-tor `[- doc]`; vocab doc artifact kept | verified-dead→removed | callsteps grep = 0; regen: 14 tors + say, 0 contract refs |
| 22 | nested field path | `{{u.name.first_name}}`, `u.payment_methods.X.amount` | refused: `the bound value 'u' carries no field 'name.first_name'` — although `u.name` IS a record holding `first_name`. Paths split at the first dot only (`interpreter.interp.kz` `interpolateRef`, `interpreter.expr.kz` lone-field path) | **fixed, koru `b9671ab00`** — resolves at any depth; probe H1 `{{u.name.first_name}}` → `say "Mia"`, H2 bare arg resolves before dispatch; pin 440_060. Was verified-narrowing (refusal text misleads) | probe case B renders `{{u.name}}` as `{"first_name":…}`; receipts (all `callsteps*.jsonl`, deduped, mixed protocol epochs): 32× `u \| name.first_name`, 9× `payment_methods.*.amount`. Compiled-surface verdict on the same path: unmeasured |
| 23 | same name in sibling arms | `\| missing p \|> …` + `\| too-large p \|> …` | interpreter refuses `Shadowing not allowed: binding already exists`; compiler accepts (disjoint arm scopes) | **fixed, koru `b9671ab00`** — siblings legal, ancestor re-bind refused with KORU106 wording; probe G1 → `OK`; pin 440_059. Was gap (open since 2026-09-12) | `challenges/bridge-mirror/catalog/2026-09-12-branch-arms.md`; the refusing walk `validateFlowRecursive` (`interpreter.checks.kz`) is unchanged at koru `8a78f248c` — source read, not re-probed this session |

## Cell #4 — CLOSED 2026-11-15 (was the disputed one)

Probed through `TauGateSession` (the protocol-correct harness —
`GateSession.send` desyncs on CALLSTEPS-BEGIN; do not hand-roll):

```
say(text: "a") |>                  -> ERROR  unknown field '(text: "a") |>' on 'say'
say(text: "a") |> say(text: "b")   -> REJECT Invalid invocation syntax
note |> say |> note                -> REJECT residue bound: r1
say(text: "a") | ok x |>           -> say emitted + status:OK say bound=   ← arm ACCEPTED (binds empty — see cell #6)
say(text:"a")\n    say(text:"b")   -> two says, STEPS — indent = separate items
```

Superseded 2026-11-15 (cells #3, #4, #6): say/note are void tors. A
bare `|>` after them sequences; an arm on them is refused. The refusals
above measured a bridge parser gap (koru `9f527faea` fixed it).

## What Fable's session should audit (interpreter side)

- ~~`std/bridge` pipe semantics~~ — closed, cell #5: a bare `|>` after a
  call is refused; data moves only through named arms.
- ~~Arm words on void tors~~ — closed, cell #6: refused.
- call_step records vanish after an armed item: in a multi-item turn,
  dispatches after a `| word name |>` item (and that arm's own
  continuation) write no call_step — gate_probe `call_step coverage`
  22/24. Measured identical at koru `b9671ab00`, so it predates the
  void-pipe work. Open.
- Residue binding: bare prose mints rN with the raw text — is that the
  intended custody story or an accident?
- Validation-error diagnostics: `unknown field '(text:...) |>'` names the
  symptom, not the fix — should the gate teach ("say is a statement")?
- Guide timing (cell #15): guides fire at dispatch. Knowledge the model
  needs *before* its first dispatch cannot come from a guide and may not
  come from a fetched manual (`contract()` is removed and banned) — it
  has to be computed into the per-tor `[- doc]` declarations and the
  affordances render.

## Resource bridge — the string-handle projection (added 2026-11-15)

The wire shows handles as `rN` strings with `<type>` phantom tags. The
interpreter's pool is richer (`interpreter.handles.kz`,
`bridge.affordances-render.kz`): each `Handle` carries `handle_id`,
`obligation_name`, `obligation_module`, `discharge_event`, `discharged`,
plus `hasUndischargedDependents` — a dependency graph the wire never sees.

| Layer | Wire sees | Interpreter holds | Gap |
|-------|-----------|-------------------|-----|
| identity | `r1`, `u`, `c1` strings | `handle_id` in pool | name-only; no module qualification |
| type | `string<reservation-known>` phantom tag | `obligation_name` + `obligation_module` | module lost — two scopes' `found` collide |
| lifecycle | bound in result, gone at discharge | `discharged` flag + `discharge_event` provenance | wire can't ask *why* a handle died |
| custody | "pass the binding name" prose rule | `hasUndischargedDependents` graph | dependents invisible — release-order bugs possible |
| resources beyond handles | nothing | stores, channels, `*T<state!>` fields, custody witnesses (the ~2000-test language surface) | wire exposes ONLY the handle-pool slice |

**The question for Fable:** is `rN`+phantom-tag the right *projection* of
the interpreter's resource model, or should wire handles carry richer
identity — module-qualified obligation refs, dependency edges, discharge
provenance? The regression suite is the reference for what "resource" means
in the language proper; the wire currently approximates it with strings.
Cells to add to the matrix once the resource section is scoped: phantom
`<type>` vs `<!type>` vs `type!` enforcement parity (compile vs dispatch),
dependent-release ordering, module-qualified obligation collisions.

## Teaching-surface audit (after matrix is green)

- `native_protocol.k` contract text vs verified column — every "never/always"
  claim needs a cell.
- `airline_guides.k` rows vs verified column — guides teach post-dispatch;
  anything the model must know BEFORE first dispatch belongs in the tor declarations / affordances render (no contract surface exists).
- Seed text (`tau-agent.k` seed) vs verified shapes — the seed is fiction-in-
  history (never executes); does it teach shapes the gate would reject?
- `tau_wire.kz` pick-model tier table (committed 0f68d5d) — per-verb
  difficulty tags are experiential annotations; audit against receipt
  callsteps once enough trajectories exist.
