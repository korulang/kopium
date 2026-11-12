# STATUS-LOCALPROBE — can a local model emit valid KOPIUM wire?

**Verdict: YES — the local path is viable at the wire layer.** 24/24
completions (2 models × 4 real prompt shapes × 3 temperatures) produced
non-empty wire text the gate parsed and ran. Zero REJECTs, zero
parse-errors, zero residue/prose, zero hallucinated verbs, zero
truncations (`done_reason=stop` everywhere, eval ≤ 818 tokens).

Probe date: 2026-11-12. Endpoint: Ollama `localhost:11434` only.
Artifacts: `bench/results/localprobe/` (raw prompts, requests,
responses, gate transcripts, `probe.py`, `summary.json`). Uncommitted.

## Setup (what was actually measured)

- **Prompts**: real recorded agent requests, replayed verbatim — the
  exact `messages[]` arrays from R2 sweep receipts
  (`bench/results/r2/sweep/`), not paraphrases:
  - `turn1` — task0/trial0 `call_001.json` (3 msgs: system + canned
    example + first user turn; cancel-reservation request)
  - `turn4` — task0/trial0 `call_004.json` (12 msgs, deep mid-thread
    with tool-result payloads; user pushing back on refund denial)
  - `book` — task23/trial0 `call_013.json` (34 msgs; user approves
    split booking → correct move is `book-reservation` with composite
    `"quoted" JSON` args — the hardest wire shape in the vocabulary)
  - `bookretry` — task23/trial0 `call_014.json` (36 msgs; prior
    book-reservation ended `unhandled-branch: error` — gift-card
    balance; tests `| error e |>` arming awareness)
- **Request shape**: Ollama `/api/chat`, `stream:false`,
  `options.num_ctx=16384`, `num_predict=4096`, temps {0.0, 0.7, 0.3}.
  Dropped receipt-only fields (`stream`, `stream_options`,
  `reasoning.effort` — OpenRouter-specific). System prompt is the
  gate-rendered 19.6k-char grammar+vocabulary+tool-contract, verbatim.
- **Models**: `qwen2.5-coder:14b` (primary), `qwen2.5-coder:7b-instruct`.
- **Validator**: `bench/airline-gate-binary` via
  `bench/tau_gate_session.py::TauGateSession` — the same
  `std/bridge:run` gate the agent uses; fresh process per attempt;
  `say` events drained read-only, `call` events answered with the
  gate_probe-canonical stub `{"ok":true}`. Divergent/edge cases
  re-verified on `bench/wire-repl-binary` — the agent's own
  bridge+`app/tau_wire` emit path (what `tau-agent.k` actually runs).

## Scoreboard (gate verdict per attempt)

| shape | 14b t0.0 | 14b t0.3 | 14b t0.7 | 7b t0.0 | 7b t0.3 | 7b t0.7 |
|---|---|---|---|---|---|---|
| turn1 | see note¹ | STEPS | STEPS | STEPS | STEPS | STEPS |
| turn4 | OK | OK | OK | OK | OK | OK |
| book | STEPS² | STEPS | STEPS³ | STEPS | STEPS | STEPS |
| bookretry | OK | OK | OK | OK | OK | OK |

¹ turn1/14b/t0.0: gate-binary **panicked (SIGABRT)** — see finding A.
On the agent path (`wire-repl-binary`) the same output ran clean:
2-item program, call dispatched, say dispatch-errored on two
hallucinated splice fields (`r.payment_methods`, `r.baggages` — the
real reservation payload carries `payment_history` /
`total_baggages`+`nonfree_baggages`; verified against the recorded
payload). Wire VALID; semantic splice misses → say reaches nobody.

² book/14b/t0.0: syntactically valid `book-reservation` ×3 + say, but
**omitted required args** `total_baggages`, `nonfree_baggages`,
`insurance` → every step `dispatch-error: field 'total_baggages'
expected i64, got ''`; the say then failed on `{ mohamed_res }`
unbound (the `| ok` arms never fired). Wire parses; args incomplete.

³ book/14b/t0.7: wire parses and dispatches, but the model wrote
`"amount": 1,094` (comma) inside the `payment_methods` composite
payload → the gate's lenient inner-JSON parse re-emits the call event
as **malformed JSON** (`"amount": 1,094` raw). Verified byte-level on
`wire-repl-binary`: `json.loads` fails at char 563 — exactly where
`KopiumAgent._recv` would raise `RuntimeError: non-JSON line` and kill
the run. See finding B.

STEPS is the normal verdict for multi-item replies (the `partial`
report); OK for single-item. No attempt produced REJECT, HALT,
validation-error at parse level, residue, or empty output.

## What the models actually emitted (verbatim)

14b, book/t0.3 — full composite-arg program, all three bookings
dispatched `ok` by the gate:

```
book-reservation(user_id: "mohamed_silva_9265", origin: "JFK",
  destination: "SFO", flight_type: "round_trip", cabin: "business",
  flights: "[{\"flight_number\": \"HAT083\", \"date\": \"2024-05-26\"},
            {\"flight_number\": \"HAT274\", \"date\": \"2024-05-28\"}]",
  passengers: "[{\"first_name\": \"Mohamed\", ...}]",
  payment_methods: "[{\"payment_id\": \"certificate_3765295\", ...}]",
  total_baggages: 0, nonfree_baggages: 0, insurance: "no") | ok mohamed_res |>
book-reservation(...) | ok raj_res |>
book-reservation(...) | ok liam_res |>
say(text: "Your reservations have been successfully updated. ...")
```

7b, book/t0.0 — wire-valid but semantically derailed: ignored
`book-reservation` entirely and emitted `send-certificate` ×3 (the
vocab's "Be careful!" verb) + `update-reservation-baggages` ×3 +
`calculate` + say — all dispatched ok. Valid wire, bad agent.

14b, turn4 — all six attempts across both models emitted a single
`say(text: "...")` (ask-for-info / promise-to-check replies). Valid,
lazy — nobody retried a tool call deep in the thread.

## Failure modes found (none blocked wire-validity)

- **A. `airline-gate-binary` panics on blank-line-inside-string.** The
  turn1/14b/t0.0 output put literal newlines inside `say(text: "...")`
  including a blank line. `gate_intake` reads to the first blank line
  (string-unaware), so the tail (`Please confirm...")`) stayed in
  stdin; the blocked `callIO` then read it as an inbound line →
  `SIGABRT` (`rc=-6`, panic in `dispatchThroughScope`/`runSteps`,
  `output_emitted.zig:1278`). Deterministic repro
  (`/tmp/lp_wire_t00.txt`). **The agent path does not crash**: on
  `wire-repl-binary` `bridge:run` takes the whole source string,
  string-aware segmentation folds the newlines, the program runs as 2
  items. So: legal wire per the real path + a gate-binary intake bug
  (its protocol diverges from `bridge:run` on this input). In a bench
  run this input would kill the gate process, not just reject.
- **B. Composite-arg `1,094` → malformed call-event JSON → marshal
  death.** Gate parses the quoted-JSON payload leniently, re-emits
  `arguments` as strict JSON, and `1,094` survives as an invalid
  number literal. `KopiumAgent._recv` does bare `json.loads` →
  RuntimeError → run over. Gate/marshal robustness bug triggered by a
  one-character model slip.
- **C. Semantic misses the wire can't see**: hallucinated splice
  fields (turn1 t0.0), omitted required args (book t0.0), wrong-verb
  plans (7b book). All counted "valid wire" here; all would score
  poorly in a real run.

## Honest limits

- Viability signal, not an evaluation: 24 samples, one domain, three
  prompt shapes from two tasks. "Valid wire" ≠ "good agent" — 7b's
  12/12 says nothing about task performance; several replies were
  semantically lazy or wrong.
- Call results were the stub `{"ok":true}` — splice/field failures
  are under-detected relative to real payloads (though the two
  hallucinated fields flagged above were checked against the real
  recorded payload and would fail there too).
- `tau-agent-binary` itself was not run (it needs a model endpoint);
  `wire-repl-binary` shares its bridge + `tau_wire` emit path and was
  used for the divergent cases — high confidence, not the same
  binary.
- Request params deviated from receipts: `num_ctx=16384`,
  `num_predict=4096` (receipt used `max_tokens=16384`), no
  `reasoning.effort`, non-streaming. No attempt hit the cap.
- Temp-0 on Ollama is near- but not perfectly deterministic; the
  0.3/0.7 rows are the spread, not resamples.

## Bottom line for the parent

Local models CAN emit valid KOPIUM wire — the thesis survives its
$0 test. The binding constraints are semantic (field names, arg
completeness, task judgment — exactly what R2's corpus measures), not
syntactic. Two gate-side robustness bugs surfaced that are worth
fixing regardless of model choice: the gate-binary's string-unaware
blank-line intake (panic, not REJECT) and the lenient-inner/strict-
outer JSON re-emission that produces marshal-killing call lines.
