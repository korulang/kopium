---
type: belief
id: frag-callstep-records-can-vanish
ts: 2026-11-15
tags: [kopium, receipts, call_step, measurement, harness]
provenance: gate_probe `call_step coverage` red at 22/24; traced to koru
  renderHeldHandles writing handle ids unescaped (fixed a48213855) and
  tau_gate_session skipping malformed CALLSTEPS lines without a word
---

# frag-callstep-records-can-vanish

**Belief:** a call_step corpus is only as complete as its parser is
loud. Records made before koru `a48213855` vanish whenever a handle
carrying JSON text was held — in practice every step after an armed
call in a multi-item turn. Any count, ratio or outcome mix computed from
`callsteps*.jsonl` recorded before that commit undercounts exactly the
turns where the model chained successfully, so it is biased toward
failure shapes, not merely noisy.

**Why:** the gap sat behind two layers that each looked fine alone. The
gate emitted every record; the session read every line; the harness
dropped what it couldn't parse and said nothing. A skip that keeps the
protocol in sync is not a reason to stay quiet — a malformed record is
now a `callstep_parse_error` record, visible in every consumer.

**Open questions:** which published or relied-on numbers were computed
from pre-fix callsteps, and do any conclusions flip once the missing
post-arm steps are counted? Is re-recording the affected runs worth it,
or is marking them pre-fix enough?
