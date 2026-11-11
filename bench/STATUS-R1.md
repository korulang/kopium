# STATUS-R1 — call_step coverage invariant

**Verdict: done**

Every item of every turn yields ≥1 `call_step` record on both agent paths.
The remaining hole — items that pass the wire gate but produce a
zero-dispatch outcome inside `run` (interpreter parse-error,
validation-error, scope-not-found, pre-first-arm budget exhaustion) —
is closed at the single dispatch boundary. Parity between the gate path
and the tau-agent path is verified identical on a 5-turn scripted wire.

## Files changed

kopium (`/Users/larsde/src/kopium`, uncommitted):

- `bench/tau-agent.k` — `send` binds `app/tau_wire:api-url()` before
  `add.post`; URL now env-overridable (default unchanged).
- `bench/tau_wire.kz` — new `api-url` tor: `KOPIUM_API_URL` env or the
  real OpenRouter endpoint. Exists so the parity harness can point the
  whole ask→drive→act path at a local stub with zero model spend.
- `bench/callstep_parity.py` — NEW: parity driver + local SSE stub.

koru (`/Users/larsde/src/koru`, uncommitted; `.kz` stdlib only, no `src/`):

- `koru_std/bridge.calls.kz` — new `outcomeDetail(r)` helper: the
  `error` text for a zero-dispatch item record, extracted per
  `run_event.Output` variant.
- `koru_std/bridge.dispatch.kz` — `dispatchAndRecord` emits
  `emitItemRecord(br, outcomeKind(d.out), outcomeDetail(d.out), "",
  step, of, sh)` when `d.steps.len == 0`. One boundary covers every
  zero-dispatch outcome uniformly; additive — records appear only where
  previously none did.

Rebuilt binaries (build artifacts, not source): `bench/airline-gate-binary`,
`bench/tau-agent-binary`, `bench/mock-gate-binary`.

Pre-existing landed work verified, not changed this session:
`run_start` trial/seed/gate_sha (`bench/run_airline_local.py:72-82`),
`origin` marker + `write-callsteps` drain (`bench/tau_wire.kz`,
`bench/tau_gate_session.py`, `bench/airline_llada_agent.py`),
item-record machinery (`koru_std/bridge.itemrec.kz`, commit `30d45b148`).

## The hole, reproduced then fixed

Before the fix (stale binary probe, `get-user-details(user_id:"x") |
bogusarm u |>` + `say` second item — a `validation-error`, zero
dispatches):

```
status STEPS step 1/2 validation-error: 'bogusarm' is not an outcome ...
REC t=1 s=2 of=2 out=result verb='say'        # step 1: NO record
```

After rebuild:

```
REC t=1 s=1 of=2 out=validation-error verb='' err="'bogusarm' is not an outcome of 'get-user-details' — it issues ok | er"
REC t=1 s=2 of=2 out=result verb='say' err=''
```

## Verification 1 — gate_probe (verbatim tail)

```
  PASS     call_step: every item yields a record (refusal+chain+unbound)  [0.0s]

24/24 passed
```

All 24 cases PASS; no previously-green case regressed. (The coverage
case itself was already green on the pre-fix binary — koru commit
`30d45b148` had landed itemrec + pre-eval arming. The residual hole this
session closed — zero-dispatch outcomes inside `run` — is not covered by
that case; verified by the inline probe above.)

## Verification 2 — parity (verbatim)

`python3 bench/callstep_parity.py` — 5 scripted turns through
`TauGateSession(airline-gate-binary)` vs `tau-agent-binary` with
`KOPIUM_API_URL` pointed at a local SSE stub (no model spend; the real
ask→send→SSE→drive→act→drain-calls→write-callsteps path runs end to end):

```
=== gate path (airline-gate-binary): 11 records ===
  t=1 s=1/1 out=result verb='say' seq=1 origin=model
  t=2 s=1/2 out=result verb='get-user-details' seq=2 origin=model
  t=2 s=2/2 out=result verb='say' seq=3 origin=model
  t=3 s=1/3 out=residue verb='' seq=4 origin=model
  t=3 s=2/3 out=result verb='get-user-details' seq=5 origin=model
  t=3 s=2/3 out=result verb='say' seq=6 origin=model
  t=3 s=3/3 out=dispatch-error verb='say' seq=7 origin=model
  t=4 s=1/2 out=result verb='say' seq=8 origin=model
  t=4 s=2/2 out=result verb='say' seq=9 origin=model
  t=5 s=1/2 out=result verb='get-flight-status' seq=10 origin=model
  t=5 s=2/2 out=result verb='say' seq=11 origin=model
=== agent path (tau-agent-binary): 11 records ===
  (identical rows, seq and origin included)
=== compare ===
gate : [(1, 1, 'say', 'result'), (2, 1, 'get-user-details', 'result'), (2, 2, 'say', 'result'), (3, 1, '', 'residue'), (3, 2, 'get-user-details', 'result'), (3, 2, 'say', 'result'), (3, 3, 'say', 'dispatch-error'), (4, 1, 'say', 'result'), (4, 2, 'say', 'result'), (5, 1, 'get-flight-status', 'result'), (5, 2, 'say', 'result')]
agent: [(1, 1, 'say', 'result'), (2, 1, 'get-user-details', 'result'), (2, 2, 'say', 'result'), (3, 1, '', 'residue'), (3, 2, 'get-user-details', 'result'), (3, 2, 'say', 'result'), (3, 3, 'say', 'dispatch-error'), (4, 1, 'say', 'result'), (4, 2, 'say', 'result'), (5, 1, 'get-flight-status', 'result'), (5, 2, 'say', 'result')]
PARITY: IDENTICAL (11 records)
```

Scripted turns cover: say-only, cross-line arm chain, one-line chain,
prose residue + unbound-name arg-eval failure (the coverage wire),
say-arm binding, and a result-feeding call. `seq` also matched 1:1.

## Verification 3 — run_start stamp

`bench/run_airline_local.py:72-82` (only `RunLogger` emitter) emits, per
run:

```python
rlog.event(
    "run_start", task=task_id, domain="airline",
    agent="airline-llada", arm=arm, steps=steps, draft=draft,
    ..., user_sim=llm, gate=GATE.name,
    gate_sha=hashlib.sha256(GATE.read_bytes()).hexdigest()[:12],
    trial=trial, seed=42 + trial,
)
```

`trial` from `--trial`, `seed=42+trial` (the orchestrator seed),
`gate_sha` = real sha256[:12] of `airline-gate-binary`. All populated
with real values. Landed earlier (commit `6854908`); verified present.

## Verification 4 — git status

kopium: `M bench/tau-agent.k`, `M bench/tau_wire.kz`,
`?? bench/callstep_parity.py` (+ pre-existing unrelated untracked files,
untouched). koru: `M koru_std/bridge.calls.kz`,
`M koru_std/bridge.dispatch.kz` (+ unrelated in-flight edits to
`koru_std/guide.kz`, `koru_std/index.kz`, `src/*.zig` from other
sessions — not mine, untouched). No commits made anywhere.

## Record-schema delta

**No new fields.** The fix emits the existing item-record shape
(`emitItemRecord`) for outcomes that previously produced zero records:

- `verb`: `""` (empty — no dispatch occurred)
- `item_outcome`: the run outcome verbatim
  (`parse-error`, `validation-error`, `shape-error`, `event-denied`,
  `dispatch-error`, `scope-not-found`, `exhausted`, or defensively
  `result`/`unhandled-branch`)
- `error`: the variant's own message (`outcomeDetail`)
- `failed`: `false` (unchanged semantics — item records are not
  dispatch failures)
- all other fields as `emitItemRecord` already emits them

Consumers checked: `runlog.py`/`airline_llada_agent.py` log records
verbatim; `TauGateSession.drain_callsteps` parses the fixed field set;
`write-callsteps` injects `origin` textually; portal reads runlog JSONL
event fields opaquely. No consumer keys on record *count* per item, so
added records are safe. `grep call_step` surfaces: bench only — no
analysis scripts break.

## Unverifiable / residual

- `gate_probe` has no permanent case pinning the zero-dispatch-outcome
  record (validation-error). Verified this session via inline probe;
  a dedicated case is a cheap follow-up.
- `run_start` exists only on the airline-llada path (sole `RunLogger`
  emitter). The tau-agent path's receipts are `callsteps_*.jsonl` +
  `session.json` — no run_start equivalent there; flagged, not built.
- `seed=42+trial` is the tau2 orchestrator seed; the agent's own gen
  `seed` param defaults to 0 and is not wired to it. Honest as logged
  (it names the run's seed), noted for the record.
- Parity's agent side ran against a local SSE stub via the new
  `KOPIUM_API_URL` — every component except the provider HTTP endpoint
  is the real path. SSE framing is OpenAI-shaped `data:` lines, the
  format `koru/sse:feed` consumes.
