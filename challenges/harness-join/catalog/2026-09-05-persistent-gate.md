# persistent-gate

One long-lived gate process; many Koru lines; the same `Bridge`.

`KopiumAgent._gate` used to `subprocess.run` `*-gate-binary` per line
(`airline-gate.k` / `mock-gate.k` minted a bridge, ran once, exited).
It now holds a `GateSession` (`bench/gate_session.py`): one `Popen`,
one line in / one line out. The gate programs `[with] create` once and
`serve` via `std/io:readln` until stdin EOF.

Ran: `python3 bench/probe_persist.py` → exit 0
```
line1 OK say …
line2 OK say …
alive_between True
PASS: one process, two lines, same Bridge
```

Zero tokens. `defined` landed on the next card
(`2026-09-05-define-on-gate.md`).

Also: `std/io:readln` was a stub (`readln not yet implemented`). It now
blocks one line; pinned by koru `650_009_readln_one_line`.

Would correct: `probe_persist.py` fails, or `_gate` spawns a process per
line again, or the gate creates a new bridge per invocation.
