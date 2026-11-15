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
| 3 | say emitting pipe | `say(text: "...") \|>` | contract says ILLEGAL ("never append continuation arrow") | verified-rejected | task7 receipts: `unknown field '(text:...) |>' on 'say'` ×10 |
| 4 | say mid-pipe | `prev |> say(text:"...") \|> next` | user asserts legal; contract implies illegal | **DISPUTED — first cell to close** | probe wires below |
| 5 | void-step piping | does `\|>` pipe data or sequence? | unknown — say/note return void | assumed | interpreter audit (Fable) |
| 6 | say with outcome arm | `say(...) \| ok x \|>` | contract says illegal | assumed | same probe batch as #4 |
| 7 | note | `note(text: "...")` | emit-only, observer lane, void | verified | receipts; `observer:` history msgs |
| 8 | residue | bare prose / unparseable | binds rN, reaches nobody, reasoning only | verified | receipts; REJECT verdicts |
| 9 | multi-item turn | newline-separated items, indent continuation | items run in order; indent = pipeline continuation | partially verified | resp_*.txt shapes; needs pipe-semantics pin |
| 10 | labeled args | `verb(field: value)` | required; positional rejected | verified | PARSE006 errors; gate_probe |
| 11 | phantom/binding args | `reservation: r1` vs literal | binding name required for `<type>` phantoms | verified | dispatch-errors teach it; receipts |
| 12 | branch arms | `\| found r \|>`, `\| error e \|>` | arm expected outcome; error = transport | verified | callsteps armed[] fields |
| 13 | hold→confirm custody | `hold` mints `held!`, `confirm`/`release` consume | obligation lifecycle | partially verified | clean-session test did cancel/say; hold chain unprobed end-to-end |
| 14 | select chain | search→found→select→chosen | chosen required by update/hold | asserted | contract recipe added; never observed firing in receipts |
| 15 | guide timing | `std/guide:add` fires on dispatch/resolution | post-dispatch only — cannot teach pre-dispatch refusals | verified | frag-guidance-fires-on-resolution; task7 refusal evidence |
| 16 | watch identical-call | repeated call+result → error branch | WMFX no-op signal | verified | `unhandled-branch: error` in receipts |
| 17 | introspection verbs | vocabulary/grammar/state/contract/bind/abandon | host verbs, always callable | asserted | bind used by gate_session; others unprobed this session |
| 18 | define | `define name { ... }` | session invention joins vocabulary | asserted | probe_session_mock covers mock scope |
| 19 | `expr: Expression` args | `tor f { expr: Expression }` | exists in koru_std (array sort `[norun|expand]`, cell, channel) | assumed-for-emit | would `say { expr: Expression }` legalize `say("...")`? unprobed |
| 20 | `@"path"` literal | `f(@"file.md")` | NOT Koru — passes frontend, dies in backend | verified-hole | koru red test `100_089_at_string_literal_passes_parser` (2183477d0) |

## Cell #4 — the disputed one (close first)

Exact wires to run through `gate_probe.py`'s harness (it drains
STEPS/CALLSTEPS correctly — do NOT hand-roll `GateSession.send`, it desyncs
on CALLSTEPS-BEGIN blocks):

```
say(text: "a") |>                                   # baseline: rejected?
note(text: "n") |> say(text: "a") |> note(text: "m")  # say mid-pipe, emit-only chain
say(text: "a") | ok x |>                            # say + outcome arm
say(text: "a")\n    say(text: "b")                  # indented say, no pipe
call | found u |> say(text: "{{u.x}}") |> next-call  # say mid-pipe after real call
```

Expected outputs to record per wire: verdict (OK/REJECT/ERROR), item_outcome,
whether say emitted, whether next item ran. The answer decides whether the
contract's say rule is correct-as-written (#3 verified) or over-broad (#4).

## What Fable's session should audit (interpreter side)

- `std/bridge` pipe semantics: does `|>` pipe the previous step's *result*
  into the next call's args, or merely sequence? Void steps (say/note)
  emit `{"branch":""}` — what does a pipe after void actually carry?
- Residue binding: bare prose mints rN with the raw text — is that the
  intended custody story or an accident?
- Validation-error diagnostics: `unknown field '(text:...) |>'` names the
  symptom, not the fix — should the gate teach ("say is a statement")?
- Guide timing: confirm `std/guide` fires only post-dispatch (cell #15) —
  pre-dispatch doctrine must live in contract/system surface.

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
  anything the model must know BEFORE first dispatch belongs in contract.
- Seed text (`tau-agent.k` seed) vs verified shapes — the seed is fiction-in-
  history (never executes); does it teach shapes the gate would reject?
- `tau_wire.kz` pick-model tier table (committed 0f68d5d) — per-verb
  difficulty tags are experiential annotations; audit against receipt
  callsteps once enough trajectories exist.
