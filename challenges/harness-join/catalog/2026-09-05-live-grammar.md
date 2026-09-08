# live-grammar

The agent's Koru lesson is `std/bridge:grammar` on the same Bridge
(`440_017`), not a hand-typed paragraph in Python.

`live.k` warms `grammar` each turn: wire rules, compiled verbs, inventions
— the lesson and the law are one render. `KopiumAgent` still taught Koru
in host prose and listed verbs via `vocabulary()`. Those can drift from
what `run` actually judges. The gate now answers `.grammar`; after
define the render holds the wire rule *and* `greet(msg: string)`.
`KopiumAgent._system_prompt` splices that render in place of the
hand-typed grammar + vocab list. Domain policy stays host-side.

Ran: `python3 bench/probe_440_017.py` → exit 0
```
A wire line is exactly one invocation: …
Your vocabulary:
say(text: string)
define DEFINED greet
… greet(msg: string)
PASS: 440_017_bridge_grammar_renders_rules_and_inventions holds on the bench path
```

Zero tokens. Distinct from live-vocab (verb list only) and pin-440-012
(redefine body). Sibling probes still green.

Would correct: `probe_440_017.py` fails, or `_system_prompt` teaches Koru
from a Python string again, or grammar after define is only `vocabulary()`.
