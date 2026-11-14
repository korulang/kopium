---
type: belief
id: frag-receipt-first-not-run-first
provenance: kopium bench 2026-11-14 — repeated 0.0 rewards treated as model
  limitation while the request body showed wire-as-history, fake
  say-successes on rejected turns, and empty result noise the whole time
ts: 2026-11-14
tags: [kopium, bench, discipline, receipts, measurement]
---

# Receipt first, not run first (belief)

A benchmark reward is a lagging indicator; the request body
(`receipts/call_*.json`) is the oracle. Repeated identical failures are a
protocol bug until the receipts prove the surface clean — "model issue" is
blame without evidence until then. Never run-and-patch: read what the model
saw before running again. When trajectory and request body disagree, the
request body wins.
