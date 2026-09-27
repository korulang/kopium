---
type: belief
id: frag-parity-gate-failed
provenance: corrected 2026-09-27 — the refresh measurement this concept cited (koru 7/14 vs stock 12/14) was produced under a coached prompt and is void; restated against the clean receipted baseline
ts: 2026-09-27
---

# frag-parity-gate-failed

**The 2026-09-26 refresh never measured the wire.** Every koru-side number
in it ran under `DomainConfig.extra_rules` — hand-authored behavioral
clauses injected into the measured prompt, including the refusal rule
being scored (bench/CONTAMINATION-2026-09-27.md). The claimed 7/14 was a
coached arm's score; the prior version of this belief was therefore never
supported.

What the first clean baseline shows instead (prompt
`e21e17eb15e5728c`, `extra_rules` field deleted, receipted runs under
`bench/results/runs/`): 8/12 airline tasks green, with the reds all
judgment failures — *over-action* (writes the policy didn't authorize)
being the dominant class. The deleted coaching clause was compensating
for a real model weakness, not measuring one.

The standing conclusion survives weaker evidence: shared-axis parity is
still not this project's rent, but the reasoning changed — the category
claims (capability grammar, possession lifecycle, vocabulary growth) are
the measured axes; fluency-vs-function-calling is not the instrument this
harness exists to be. Any further tau2 spend is bounded smoke only, each
run receipted, prompt guarded at commit time (`bench/prompt_guard.py`,
`hooks/pre-commit`).
