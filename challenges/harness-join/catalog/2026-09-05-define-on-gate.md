# define-on-gate

`define` is legal on the bench path; the session table survives the line.

`std/bridge:run` already installs a two-statement source (`tor name { args }`
then `name = …`) into the Bridge's defined-flows table — that is turn 4 of
`headless/session.k`. The bench gate used to flatten that source onto one
line (or refuse `defined` entirely). It now takes the same two-line source
`session.k` feeds `run()`, prints `DEFINED <name>`, and the next line on
the same process dispatches the new verb.

Ran: `python3 bench/probe_define.py` → exit 0
```
define DEFINED greet
call   OK greet …
alive  True
PASS: define survived the line
```

Zero tokens. `KopiumAgent` speaks `defined <name>` on `DEFINED` (no τ³ tool).
`probe_persist.py` still green.

Would correct: `probe_define.py` fails, or `_gate` treats `DEFINED` as a
refusal, or the gate creates a new bridge between define and call.
