---
type: belief
id: frag-policy-versus-gold
provenance: measured 2026-10-19 — task 39 lost under muse, deepseek, and
  GLM (both policy placements); GLM's transcript showed a policy-faithful
  refusal of MSJ4OA while the task's db_check requires it cancelled
ts: 2026-10-19
tags: [kopium, tau2, eval, policy, task39]
---

# Policy versus gold — a task can demand looser-than-written behavior

tau2 task 39 is designed around a check the written policy does not
support. The airline policy makes travel insurance reason-conditional —
"full refund … given health or weather reasons" (policy.md:101), and
cancellation requires "the reason for cancellation is covered by
insurance" (:147). The simulator's script never supplies a
health-or-weather reason ("cancel all my flights … give up your seat for
someone else"). The evaluation criteria, however, require `MSJ4OA` —
`insurance: yes` — to be cancelled.

Every model tested (muse, deepseek, GLM, stock-deepseek) read the policy
strictly and refused `MSJ4OA`; the strict reading is the *correct*
reading of the document. GLM under policy-in-system went further:
enumerated all seven reservations, cancelled the two unambiguously
eligible, and asked the user whether the reason was health or weather —
the textbook interrogation — then refused. Reward: 0.0.

The belief: a 0.0 on a policy-application task is not automatically an
agent fault. Where the task's gold encodes a looser reading than the
document supports ("insurance=yes → cancellable", no reason check), a
policy-faithful agent is *correctly* losing. Before treating a loss as a
surface defect, read the gold's required actions against the policy text
— task 39's db_check and its own description ("doesn't cancel
reservations if the refund is not applicable") are in tension, and the
gold wins regardless of which behavior the policy actually prescribes.

Moving the policy into the system message (from a user-role turn) is
still the right placement — law belongs with the contract, not
mid-history — but it does not manufacture wins where the eval and the
document disagree.
