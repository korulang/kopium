# 2026-11-15-void-tor-pipes-and-arm-scope — void tors chain with `|>`; arm scope and field paths match the compiler

Measured this session (kopium `a5bdf80`/`7d49e10`, airline gate via
`TauGateSession` — `bench/probe_pipe_semantics.py`, `bench/gate_probe.py`;
compiled probes under `/tmp/koru-probes/phase1/`; koru `8a78f248c` before,
`b9671ab00` / `9f527faea` / `a48213855` after).

| facet | compiled `.k` | bridge before | bridge after | class |
|---|---|---|---|---|
| `void() \|> next()` | backbone — 440_050 harness chains `\|> step(...)` on a void tor | `REJECT Invalid invocation syntax` (parser split only at `\| word`) | runs in order (I1, F1) | ~~gap~~ **supported** |
| trailing `say(...) \|>` | incomplete program | misparse `unknown field '(text: "a") \|>'` | runs the say — partial program (I2) | **deferred** (Lars 2026-11-15) |
| `outcome_tor() \|> next()` | compiles (harness shape); dedicated pin: none | parse refusal | parses; outcome handed back `unhandled-branch` (A/I3) | **deferred** |
| arm on a void tor, `\| ok x \|>` / `\| ok \|>` / `\| ok _ \|>` | no passing test arms a void tor | accepted, `x` bound empty | refused: `'say' is void — it issues no outcome …; chain the next call with a bare \|>` (F2) | ~~gap~~ **refused-honest** (shape bug, Lars) |
| same name in sibling arms | compiles + runs (`n23_siblings.k`) | `Shadowing not allowed` | fired arm runs (G1) | ~~gap~~ **supported** |
| ancestor arm re-bind | `KORU106` refused (`n23_nested_rebind.k`) | unchecked in indented arms | refused with KORU106 wording (440_059) | **refused-honest** |
| `u.name.first_name` (interp + bare arg) | compiles + runs (`n22_nested_field.k`) | `carries no field 'name.first_name'` / `does not evaluate` | resolves (H1 `say "Mia"`, H2) | ~~gap~~ **supported** |

Pins: 440_059, 440_060, 440_061, 440_062; migrated 440_027, 440_050,
430_061 (renamed), 430_067. Filtered 430_/440_ after each step: the same
14 failures as the 2026-11-14 board.

Side catch: call_step records after an armed call were malformed JSON
(held-handle ids unescaped) and dropped silently by `tau_gate_session` —
fixed both ends (`a48213855`, `7d49e10`); see
`concepts/frag-callstep-records-can-vanish.md`.
