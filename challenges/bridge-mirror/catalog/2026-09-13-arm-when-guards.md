# 2026-09-13-arm-when-guards — `when` on a continuation parses, never evaluates, runs ungated

Construct: **arm-level `when` guards** — `| branch b when <expr> |> body`,
conditional arm selection the flow parser stores as `cont.condition`
(`210_004`, `100_080` pin the syntax).

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`,
probe `headless/probe_arm_when.k`; compiled probe /tmp when_compiled.k):

| surface | program | verdict | class |
|---|---|---|---|
| compiled `.k` | `check(x: 10) \| high h when h > 100 \|> … \| high h \|> …` | guard evaluated: `h > 100` false → skipped, unguarded `high` arm ran | supported |
| wire + bridge `source:` | `read(path: "…")\n\| ok t when false \|> say(…)\n\| ok u \|> say(…)` | **`result` — the guarded arm FIRED.** `FIRED-despite-false-guard` printed; the `false` literal was never evaluated | gap |
| wire + bridge `source:` | same shape, `when true` | fires — consistent with evaluation but the false case proves it is ignored | — |

`interpreter.select.kz` `selectArm` matches on branch name (or catch-all)
and never consults `c.condition` — confirmed by read *and* by run. The
parse is full-fidelity; eval drops the guard. First-match order makes the
first arm on a branch win regardless of its guard.

Why this is the worst cell so far: `runtime.parsewire.kz`'s own header
claims "the arms' grammar is the interpreter's own parser … so the wire
can never accept a chain eval would execute differently." This row is the
measured counterexample — the wire accepted `| ok t when false |>`, eval
executed it differently. A `200` that shipped wrong markup: the model can
emit a guard that runs unconditionally, nothing refuses it, and
WIRE_GRAMMAR_TEXT never mentions `when`, so the prompt teaches narrower
than the parser accepts.

Same-name sibling arms mask the measurement: `| ok t when false |>` +
`| ok t |>` dies on the catalogued `Shadowing not allowed` gap before the
guard question is reached. The distinct-binding variant is what isolates
this row.

Disposition: koru-side (`koru_std/interpreter*.kz`), same shape as
`CatchallMetatypeUnsupported` — an arm eval cannot judge must refuse, not
fire. Honoring the guard means evaluating `cont.condition` against the arm
binding (the interpreter already runs an ExpressionParser for `if`/`while`
conditions); refusing it means a named outcome at select time — never a
body that ran ungated. Whether the wire should *also* refuse `when` in
arms is the narrower question; the interpreter lie stands either way, for
`std/runtime:run` consumers too.

Would correct this row: `read(path: "…")\n| ok t when false |> say("X")\n| ok u |> say("Y")`
prints `Y` (guard honored, fell through) or reports a named refusal —
`step`/`validation`/`unhandled` naming the guard — and never prints `X`.
