---
name: bench-verify
description: The receipt-oracle discipline for KOPIUM/Tau2 benchmark work. Fire before ANY verdict — reward claims, "doesn't work," "capability floor," arm comparisons, or model-behavior conclusions — and whenever reading run output, diagnosing a trajectory, or designing an A/B. The oracle is the request bodies, not the trajectory.
---

# bench-verify — verdicts are earned from receipts, not trajectories

Burned twice on 2026-10-12: concluded "post-dispatch gap" and "capability
floor / diminishing returns" from trajectory-level reads while `call_*.json`
request bodies held the actual mechanism both times. Trajectory summaries are
narrative; receipts are evidence. This skill exists so the lookup happens
before the verdict, not after being caught.

## The oracle hierarchy (cheapest that can falsify the claim)

1. **`call_*.json`** — exact request bodies sent to the model: system prompt,
   full message list, what the model actually saw at each decision. THE
   oracle for "what did the model know when it chose X."
2. **`callsteps_*.jsonl`** — per-dispatch records: verb, branch, args,
   outcome, `fired_guides`, payload values (including injected teaching).
3. **`trajectory.txt`** — env-level view: tool calls + user/assistant text.
   Necessary but NOT sufficient — it hides rejected replies, wire programs,
   and request-body content.
4. **stdout/log** — wire> lines, observer strikes, usage. Diagnostic only.

A claim about model behavior that isn't checked against (1) is unverified.
Period. No "obvious" exceptions.

## Run anatomy

- Run dirs: `bench/results/runs/<UTC-stamp>-task<N>/`
  - `receipts/call_*.json` — one per model call, full request body
  - `receipts/callsteps_*.jsonl` — dispatch records per call
  - `receipts/session.json` — session state
  - `trajectory.txt` — the readable episode
  - `receipt.json` — run header (model, git, task)
- Local smoke: `bench/results/localsmoke/<stamp>/` + `summary.json`
- Sweep logs: `bench/results/train30-local-*.log`

## Reading a failure (the autopsy order)

1. Find the FATAL/zero-reward run dir → `trajectory.txt` for the shape.
2. Pull the LAST `call_*.json` → dump every message role+content. Look for:
   - what the model saw BEFORE the bad decision (guides? docs? demos?)
   - invisible events: refused replies never enter history — only
     `observer: N consecutive refused replies` counters appear
   - repeated identical assistant turns = zero-information loops
   - semantic errors the wire can't catch (say claims vs bound values)
3. Check `callsteps` for `fired_guides` and injected payloads (`[watch]`).
4. THEN conclude — and label the claim with its evidence class.

## Experiment protocol (arm A/B discipline)

- Same task, same model, temp 0; vary ONE thing (env flag, binary, content).
- Arm-A control must run the SAME binary minus the treatment — a sweep and
  a demo-arm on different binaries is not a controlled comparison.
- Noise floor: ~3/30 tasks flip on rerun; n=1 per arm is a signal, not a
  result. Report counts, not narratives.
- User-sim is nondeterministic — trajectory divergence ≠ treatment effect
  without the control arm.
- Every run prints a receipt header (model, git_head, dirty files) — quote
  it or the number means nothing.

## Spend and labor rules (HARD)

- Local only: `KOPIUM_API_URL=http://localhost:11434/v1/chat/completions`,
  `KOPIUM_REASONING=none`, `OPENROUTER_API_KEY=dummy`,
  `OLLAMA_API_BASE=http://localhost:11434`, model `qwen2.5-coder:14b`.
- OpenRouter/paid benchmark endpoints are BANNED — `model_guard` enforces.
- Agent labor: Devin/SWE-2 only, in-session. No omp/DeepSeek/Claude/codex
  commissions — mechanical hook `~/.config/devin/hooks/block-paid-agent-labor.sh`
  enforces (devin-kind default model only).
- "Zero-cost" claims price the WHOLE commission — worker cognition
  included — stated BEFORE starting, not after.

## Known surface quirks (measured, not guessed)

- `KOPIUM_DEMO=1` seeds transcript with exemplar exchanges at boot
  (`demo-seed`/`demo-gate` in tau-agent.k).
- `[watch]` teaching IS model-visible — it lands inside the escaped
  `"value"` JSON of step-result messages (verified: 27/29 firing runs
  have it in `call_*.json` bodies). It is semantically BURIED after the
  payload, not absent. The open fix is salience/placement (guide-line
  channel), not visibility.
- Refused PROSE replies go through `residue-verdict` — they never enter
  transcript history; only observer strike counters appear. Wire-parse
  failures (`no-program`, `empty-reply`) are a DIFFERENT path.
- Wire templates lift ONE level only: `{{ u.user_id }}` works,
  `{{ u.name.first_name }}` dispatch-errors ("carries no field").
  Seeding any program with a deeper path teaches a bug the gate refuses.
- `say` blocks for user reply; user replies land as `user:` messages via
  `observe-human`.
