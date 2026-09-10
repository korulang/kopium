# define-in-turn

A `tor ` definition and a call to it run in the **same turn** on the live path.

Under the old wire a declaration was its own turn — the second invocation was
truncated — so define→use always cost two turns, even though the bridge's
defined table is exactly what makes the second call reachable. The sequencing
path shares `br.defined` across items, so a define item followed by a dispatch
item is one turn that reports both steps. This is the growth half of
frag-partial-programs: composing a new verb and using it without paying a
round-trip per step.

Ran: `python3 bench/harness-check.py` → exit 0, `23/23` (new case
`define-in-turn`). Probe: `python3 bench/probe_define_use.py` → exit 0
```
cleaned> [tor greet { msg: string }
greet = say(text: msg)
greet(msg: "hello from the same turn")]
      hello from the same turn
PARTIAL 2/2 report=[step 1/2 defined: greet
step 2/2 result: {"branch":""}
]
```
Zero tokens. Canned through `app/wire:clean` + `std/bridge:run`, the same
intake `live.k` drives.

Would correct: `probe_define_use.py` fails; the call after the define is
`event-denied` (the defined table is not shared across items); the turn reports
one item; or the defined verb does not run.
