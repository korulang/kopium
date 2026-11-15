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
| 3 | say emitting pipe | `say(text: "...") \|>` | contract said ILLEGAL — **confirmed** | verified | TauGateSession probe: `unknown field '(text:) |>'` |
| 4 | say mid-pipe | `prev |> say(...) \|> next` | **CLOSED 2026-11-15: ILLEGAL.** say/note are emit-only terminals — may receive `\|>` input and take an outcome arm, cannot emit `\|>` forward | verified | probes: `say|>say`→REJECT invalid syntax; `note|>say|>note`→REJECT residue |
| 5 | `\|>` after a call | does `\|>` pipe data or sequence? | **CLOSED 2026-11-15: neither — a bare `\|>` after a call is a parse refusal.** Data moves only through a named arm (`\| found u \|>`); the arm name is bound for the rest of the turn (later items see it); an unarmed result is still parked as durable `rN` + `unhandled-branch` report, sibling items keep running | verified | `bench/probe_pipe_semantics.py` (rerunnable; local output `bench/receipts/probe_pipe_semantics.out`, gitignored) cases A–E: bare pipe → `REJECT Invalid invocation syntax` (no call emitted, ok and error feed alike); `\| found u \|>` → `{{u.name}}` renders; binding crosses items; unarmed → `step 2/2 dispatch-error … 'u' … not bound` |
| 6 | say with outcome arm | `say(...) \| ok x \|>` | accepted — but **binds an EMPTY value, not the emitted text** (`{{x}}` → `""`). `say` declares no outcomes, yet `ok` is not refused the way `'ok' is not an outcome of 'get-reservation-details'` is | **disputed** | probe case F2 (`say -> {"branch":""} as x`, second say text `""`); measured against koru with uncommitted `koru_std/bridge.bind.kz` (void values skip `rN`). gate_probe docstring claim "binds the EMITTED TEXT" is stale at this binary. Compiler verdict on an arm over a void tor: unmeasured |
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
| 22 | nested field path | `{{u.name.first_name}}`, `u.payment_methods.X.amount` | refused: `the bound value 'u' carries no field 'name.first_name'` — although `u.name` IS a record holding `first_name`. Paths split at the first dot only (`interpreter.interp.kz` `interpolateRef`, `interpreter.expr.kz` lone-field path) | verified-narrowing (refusal text misleads) | probe case B renders `{{u.name}}` as `{"first_name":…}`; receipts (all `callsteps*.jsonl`, deduped, mixed protocol epochs): 32× `u \| name.first_name`, 9× `payment_methods.*.amount`. Compiled-surface verdict on the same path: unmeasured |
| 23 | same name in sibling arms | `\| missing p \|> …` + `\| too-large p \|> …` | interpreter refuses `Shadowing not allowed: binding already exists`; compiler accepts (disjoint arm scopes) | gap (open since 2026-09-12) | `challenges/bridge-mirror/catalog/2026-09-12-branch-arms.md`; the refusing walk `validateFlowRecursive` (`interpreter.checks.kz`) is unchanged at koru `8a78f248c` — source read, not re-probed this session |

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

Verdict: say/note are emit-only **terminals** — receive `|>` input, may
take `| ok x |>` (accepted, but binds an empty value — cell #6), never
emit `|>` forward. The deleted contract text had the continuation arrow
right; whether the outcome arm should be legal at all is now disputed.

## What Fable's session should audit (interpreter side)

- ~~`std/bridge` pipe semantics~~ — closed, cell #5: a bare `|>` after a
  call is refused; data moves only through named arms.
- Arm words on void tors (cell #6): `say(...) | ok x |>` is accepted and
  binds nothing, while an undeclared arm word on any outcome-bearing verb
  is refused. Either refuse it the same way or give it a meaning the
  compiler shares.
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
