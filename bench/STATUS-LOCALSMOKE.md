# STATUS-LOCALSMOKE — live local-model smoke of the R4 guide layer

**Verdict: the doctrine layer is LIVE on a real model run.** `qwen2.5-coder:14b`
via Ollama (`localhost:11434`, OpenAI-compatible) drove `tau-agent-binary`
end-to-end; guides fired at dispatch, full template text reached the
model-visible request bodies, `fired_guides` recorded the keys, once-per-
session held, zero protocol deaths. Benchmark-side spend: **$0** (localhost
only; the smoke script refuses non-local endpoints by construction).

Receipts (gitignored, local): `bench/results/localsmoke/20261112T055220Z/`
— `summary.json` + per-call request/response/callstep files.

## What ran

`bench/live_guides_smoke.py` — drives `tau-agent-binary` against a live model
with scripted user turns, real tau2 airline env for tool results, and reports
guide evidence. Env: `KOPIUM_API_URL=http://localhost:11434/v1/chat/completions`,
`KOPIUM_MODEL=qwen2.5-coder:14b`, dummy bearer (ollama ignores auth).

Scripted turns: account lookup → reservation details → thanks.
Outbound: `get_user_details` → `say` → `get_reservation_details` → `say` →
`say` — all wire-clean, all call events valid JSON.

## Evidence (from summary.json + receipts, verified by reading them)

- `fired_guides` populated on live dispatches:
  `get-user-details->ok`, `get-user-details`, `get-reservation-details->ok`,
  `get-reservation-details`, `*->error`.
- Guide TEXT reached the model: `call_003.json` request body contains full
  `guide <key>: <template>` lines — field-truth rows (real payload key
  names), workflow exemplars (`get-user-details → get-reservation-details`),
  and the `*->error` adjudication frame.
- Once-per-session: no violations.
- `*->error` fired on a `say` that genuinely failed (`failed:true`,
  `dispatch-error`) — correct edge mapping, not a misfire.

## Anomalies checked and resolved

- `guide_texts_in_report: []` in the smoke summary — the script looked in the
  wrong field; the actual request bodies carry the full guide text. Report-
  channel rendering is a separate surface worth a follow-up look, but the
  model-visible channel is proven.

## Honest limits

- **Semantic effect unmeasured.** The model saw the doctrine; whether it
  changes choices/reward needs a task-level run (next step: 1–3 train-30
  tasks end-to-end, still $0).
- One semantic miss observed: model emitted `reservation_id: "EHGLP3"` with
  no ID provided (hallucinated binding) — exactly the class Phase-B
  live-binding exemplars target.
- `say`-edge guide text says "tool call failed" generically — fine for tools,
  slightly off-register for `say`; cosmetic.
- Session was killed mid-analysis by operator order; this document was
  written afterward from the preserved receipts — every claim above was
  re-verified against `summary.json`/`call_*.json`/`callsteps_*.jsonl`, not
  relayed.
