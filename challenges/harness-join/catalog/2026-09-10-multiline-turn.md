# multiline-turn

The bridge's multi-item sequencing holds on the agent's own intake path —
`app/wire:clean` keeps the whole turn and `std/bridge:run` reports one line per
step — not only in raw Koru.

The old wire truncated a reply to its head in `wire:clean` and reported the
drop in `extra-lines`; a second invocation could never reach the bridge, so the
τ³ agent path was a fork from the long-running bridge the toolchain now
sequences. The flip: `clean` returns the whole fence-stripped turn; `extra-lines`
is retired; `live.k`/`headed.k`/`session.k` handle the `?partial` branch and the
two hand-typed "one invocation / only the head ran" strings are gone. The join is
that the bridge's sequencing survives the live intake — not a bench-only gate.

The same replay closed the adjacent seam the flip exposed: `headed.k` had not
compiled since `5c683fc` ("consumers: bridge:run callers gain the
unhandled-branch arm") — the new arm stole the `result` arm's `announce(ma.text)`
continuation, leaving `ma` out of scope. Fixed, and the wall now compiles every
`std/bridge:run` caller (`consumers`), so a broken consumer is a red case rather
than a surprise.

Ran: `python3 bench/harness-check.py` → exit 0, `22/22` (new cases `multiline`
and `consumers`). Probe: `python3 bench/probe_multiline.py` → exit 0
```
clean kept: [say(text: "one")
say(text: "two")]
partial 2/2 — both lines ran, one report per step
PASS: a multi-item turn sequences on the live drive path, canned
```
`python3 bench/probe_consumers.py` → exit 0, `session.k`/`live.k`/`headed.k`
compile. Zero tokens. `wm/run.sh`'s wire-law signal now greps `^partial 2/2`.

Live witness (muse-spark, 9 turns, 32,996 tokens; transcript beside this card):
turns 6 and 9 each composed TWO invocations in one reply and the bridge
reported `steps: 2/2 ran`. Turn 9 emitted exactly the ruled shape —
```
open(path: "turn-nine.txt") | ok h |> append(handle: h, text: "sequenced in one turn")
say(text: "both steps ran")
```
— a chain in the first item and a second invocation in the second, both run and
reported in one turn. The flip holds from where it is actually used.

Would correct: `probe_multiline.py` fails; `clean` truncates to the head again;
the bridge returns `result` (not `partial`) for a two-item turn; the prompt
restates head-only mechanics; a reverted `extra-lines` reappears on the agent
path; or a `std/bridge:run` branch is added without every consumer compiling.
