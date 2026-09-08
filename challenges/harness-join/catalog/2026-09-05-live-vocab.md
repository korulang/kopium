# live-vocab

`KopiumAgent`'s prompt vocabulary is `std/bridge:vocabulary` on the same
Bridge that runs the line.

The model used to see a one-shot `mock-vocab-binary` /
`airline-vocab-binary` (`scope-vocabulary`, no session table). Inventions
defined on the gate never entered the prompt. The gate now answers
`.vocabulary` with `VOCAB-BEGIN` … `VOCAB-END` from that process's
Bridge. After define, the render includes `greet(msg: string)`.
`KopiumAgent._vocabulary` reads that; after `DEFINED` it rebuilds the
system prompt. The vocab binaries are no longer on the agent path.

Ran: `python3 bench/probe_vocab_live.py` → exit 0
```
before: … say(text: string)   (no greet)
define DEFINED greet
after:  … say(text: string)
        greet(msg: string)
PASS: prompt vocabulary is the same Bridge that defined greet
```

Zero tokens. Persist and define probes still green.

Would correct: `probe_vocab_live.py` fails, or `_vocabulary` shells a
one-shot vocab binary again, or a define does not refresh the system
prompt.
