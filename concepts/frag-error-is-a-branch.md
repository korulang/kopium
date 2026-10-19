---
type: belief
id: frag-error-is-a-branch
provenance: kopium bench 2026-10-19 — Lars's ruling on the task-32 receipt:
  "if you're not handling the right branch, it should short-circuit and
  give you back JSON information: which branch actually fired and the
  resource handle"
ts: 2026-10-19
tags: [kopium, wire, outcomes, bridge, marshal, tau2]
---

# An environment failure is a branch, never a payload (belief)

A tool call that fails issues its failure on a declared `error` outcome
and binds under that branch's arm — it may never bind inside `ok`, where
the agent surface cannot distinguish failure from a record.

The defect that prompted the ruling was a three-layer flattening: tau2's
`ToolMessage` carries an authoritative `error: bool` (the environment sets
it when a tool raises); `kopium_agent.py` marshaled only `content`, so the
flag died at the Python boundary; `callIO` then handed a flat string to
generated procs whose tors declared a single `-> string` outcome. A
missing user therefore fired `ok` with `"Error: User ... not found"` as
the bound value. What caught it live was incidental — `{{ u.name }}`
refused because a JSON string has no `name` field. Had the error payload
carried the requested key, the lie would have reached the user
undetected. Task-32's partial chain is the receipt.

The correction is mechanical, not semantic invention — the
`unhandled-branch` short-circuit already existed in `std/bridge` for any
named branch; the flattening made it unreachable. Three layers now carry
the flag: the marshal forwards `error`, `callIO` returns
`{content, err}` and each generated proc classifies it into
`.{ .ok = ... }` / `.{ .error = ... }`, and every generated airline tor
declares `| ok string | error string`. EOF mid-call is a protocol abort
and also returns on `error`.

Verified zero-token against `wire-repl-binary`: an unarmed error stops
the reply at the firing step —
`step 1/2 unhandled-branch: error — {"branch":"error","value":"Error: ..."}
(held []); to keep going, arm it | error name |>` — no `say` ever leaves;
an armed `| error e |>` binds the reason text and the recovery `say`
reaches the user; `error: false` lands on `ok` with field splices intact.
Downstream steps of a stopped reply report as `dispatch-error` (an arm
binding that never issued, e.g. `u`, names itself unbound) — the report
stays honest about which steps were refused, not silently truncated.

Rule for any future adapter: the marshal is transport only — when the
upstream protocol carries structured outcome kinds, dropping them into a
string convention is the defect, regardless of how readable the string
is. A wire surface whose every verb declares one unnamed outcome is a
surface where failure is indistinguishable from success at the only
layer that matters.

Consequence for the receipt archive: every pre-fix transcript showing
`"Error: ..."` bound under an `ok`/`result` step is a historical artifact
of the flattening, and the partial chains in the blog post document that
era — they are evidence the gate reported honestly, not evidence the
semantics were right.
