# 2026-09-12-when-guards — `when` parses mid-turn, does not gate, eats the argument

Construct: **`when` guards on invocations** — `verb(...) when <expr>`,
conditional dispatch the compiler honors and `flow_parser` knows.

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`):

| surface | `say(text: "b") when false` | class |
|---|---|---|
| compiled `.k` | supported — guard evaluated, call skipped | — |
| single-item bridge source | `parse-error`: "one flow per turn: nothing follows the closing ')' except arms" — refused-honest | refused-honest |
| item inside a multi-item turn | **ran** — `step 2/3 result`, `say` fired with an EMPTY text; the guard neither gated nor errored | gap |

The mid-turn verdict is the worst cell in the map so far: the construct is
accepted (no parse-error), the step reports `result`, the verb executes,
and the argument arrives mangled — a `when false` that neither refused nor
honored the guard. Whatever the flow parser did with the trailing `when`,
the outcome is silent wrongness, the exact failure class this catalog
exists to name.

Disposition: same fix site as `wire-gate-scope` — the sequencing loop's
per-item validation decides whether `when` is wire-legal; the interpreter
side decides whether eval honors or loudly refuses guards. If guards are
deliberately out of the wire's power, the refusal must be the wire's own
parse-error everywhere, not silence mid-turn.

Would correct this row: `say(...) when false` mid-turn either skips with a
named step outcome or reports `step N/M parse-error`; `when true` runs the
call intact.
