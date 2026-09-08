# mock-on-session

Mock vocabulary runs on the live-session shape.

`headless/session.k` is `[with] create` + canned `run` + `std/bridge:vocabulary`
against `notes`. The bench mock register lived on two other machines:
`mock-gate.k` (serve/readln) and `mock-vocab.k` (`scope-vocabulary`, no
Bridge, no inventions). Mock now sits on the same session machine as
notes: `bench/session-mock.k`. After define, `vocabulary` lists both
compiled verbs and `greet(msg: string)`.

Ran: `python3 bench/probe_session_mock.py` → exit 0
```
defined greet — the session's vocabulary now includes it
DENIED — 'sync' is not in this agent's scope
say(text: string)
greet(msg: string)
PASS: mock register on session.k shape, vocabulary includes inventions
```

Zero tokens. Airline is the same join for the other domain — not this card.

Would correct: `probe_session_mock.py` fails, or vocabulary after define
is only `scope-vocabulary` (no `greet(`), or the program is a one-shot
gate rather than session turns.
