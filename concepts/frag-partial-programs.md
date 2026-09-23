---
type: belief
id: frag-partial-programs
provenance: Lars ruling 2026-09-07, live-define/vulcan-forcing walk — SUPERSEDED IN PART
ts: 2026-09-07
---

# Partial programs are the product; anything that forbids composition is the banned shape

KOPIUM is a system to RUN partial programs. The agent's composition —
several invocations in one turn, chained through handles the interpreter
just issued — is the load-bearing capability, not a luxury. Any prompt text,
wire rule, or grammar shape that talks the model out of composing (the
one-invocation-per-turn law, vocabulary prose that presents the verbs as
fixed and complete, goals that script single calls) makes the whole thing
useless: it refuses actual access to the interpreter while burning a full
reasoning pass per turn.

CORRECTION 2026-09-07, same night: the unhandled-branch half of this belief
was already ruled — by Lars, 2026-08-07, in koru pin 430_056
(`tests/regression/400_RUNTIME_FEATURES/430_RUNTIME/430_056_partially_handled_interpreted_flow/input.kz`):
`run` gains `| unhandled-branch { branch, payload, handles }`; leniency is a
MODE on run; strict refuses pre-flight; payload carries NAMED handles; a
model over a bridge gets the unhandled branch fed back as a message that
teaches it; KORU022 makes the host handle it. The koru-ub worktree
(rb-unhandled-branch) carries the in-flight core (`unhandled_outcome` in
interpreter context). This fragment does not originate that design — it
points at it. What this fragment still owns: the prompt-side ban (no
over-prompting, composition legal) and the wire-sequencing demand below.

# Partial programs are the product; anything that forbids composition is the banned shape

KOPIUM is a system to RUN partial programs. The agent's composition —
several invocations in one turn, chained through handles the interpreter
just issued — is the load-bearing capability, not a luxury. Any prompt text,
wire rule, or grammar shape that talks the model out of composing (the
one-invocation-per-turn law, vocabulary prose that presents the verbs as
fixed and complete, goals that script single calls) makes the whole thing
useless: it refuses actual access to the interpreter while burning a full
reasoning pass per turn.

Over-prompting is the failure mode with a fixed direction: every line of
system prompt that constrains HOW the model may act must justify itself
against the turn-cost it imposes. The disclosure principle governs —
progressive disclosure by the tools themselves, minimal seed, never a
longer system prompt. A rule that costs turns is guilty until measured
innocent (multi-invocation experiment vs the one-line law).

MEASURED 2026-09-10 — the experiment ran twice (`bench/experiment.py`;
`bench/EXPERIMENT_2026-09-10.md`). Round 1 (n=3, fixed 3-turn window): the
RELIABILITY half holds — composition 3/3 vs one-line 1/3, the misses
re-appending and corrupting the file (`alpha\nalpha`); COST was a wash (medians
within ~4%). Round 2 added a per-turn file probe so cost is measured to
COMPLETION (n=5, 4-turn headroom): composition 5/5 vs one-line 3/5, median
cost-to-completion 3,192 vs 4,203 tokens — modestly cheaper AND more reliable.
Caveats: 4/10 runs stalled at the 240s cap, and the control still allows a
single-line chain, so the law's bite is small for a chainable task.

MEASURED 2026-09-17 — the true pre-chain control ran (round 3, n=10/arm):
kopium `d7e5c3b` under koru `511392414` (= `70aeb093a~1`), whose `parse.wire`
refuses `|>` outright, so the handle crosses turns as a literal string the
model echoes back. Result INVERTS the cost claim: strict cost-to-completion
(bytes right AND bridge holding 0) median 3,512 pre-chain vs 10,622 composed —
composition ~3× MORE expensive, reliability parity (10/10 both, vs the
truncating intake's 9/10 bytes / 8/10 closed). The mechanism: the composed
model spends 2–3k reasoning tokens per turn planning chains; the serial model
spends ~300–600. Composition's measured advantage on this task is latency only
— `alpha` landed turn 1 in 6/10 composed runs vs earliest-possible turn 2
pre-chain.

What this means for the belief: the capability stays (composition is the
product — a turn that does AND confirms, and parallel-independent calls are
the untested payoff case), but "a full reasoning pass per turn" cuts the OTHER
way — serial turns are cheap passes, and the model reasons hardest exactly
when composing. The cost claim is corrected from "plausible, unproven" to
"measured false on serial-chainable tasks at this model." What would re-open
it: a task where several independent invocations collapse into one turn
(fan-out, not a serial chain) measured against the same control.

MEASURED 2026-09-17, same day — the re-opener ran (round 4,
`experiment_fanout.k`: three independent notes, open→append→close each,
n=12/15/15 across three batches after a harness panic and a binary-clobber
were found and excluded). The payoff case is REAL: composed banked all bytes
by turn 1 in 5/12 runs (three items in one reply), median done@~1.5 vs
pre-chain's metronomic done@8, lenient ctc ~2.6× cheaper (3,814 vs 10,067),
strict cost parity (9,583 vs 11,586), reliability near-parity (11–12/12 vs
15/15). The settled law is now conditional, not directional: **composition
taxes serial dependence (~3× more expensive) and pays on independence (~2.6×
cheaper, ~5× faster to first bytes)** — the model spends its reasoning budget
exactly where the structure gives it something to buy. Two refinements the
measurement adds: composed is high-variance (sctc spread 5.5× vs pre-chain's
1.2× — a bet vs a metronome), and the pre-chain model never discovered the
multi-item turn its own era allowed (the grammar teaches one invocation per
line; batching is legal and unused). Under a fixed turn cap the full-window
metric inverts (composed pays for verification turns after finishing early);
cost-to-completion is the honest measure.

IMPLEMENTED 2026-09-08 — the hand-back fires live, and the vocab-shaped
consequence is now measured:

- `notes read` returns `| ok | missing path` — the scope's first named-branch
  verb. `probe_unhandled_read.k` pins all four shapes through the same
  `std/bridge:run` (lenient) that `live.k` calls: a bare read of an absent
  path hands back `UNHANDLED branch=[missing]` (A), a partial fragment that
  handles only `| ok` hands back when `missing` fires (B), a bare read of an
  EXISTING file also hands back `UNHANDLED branch=[ok]` (C — a named branch
  nobody handled is unhandled even on success), and a handled `| ok` completes
  as `result` (D).
- Live witness: turn 5 of the 8-turn scenario (`read(path: "field-journal.txt")`)
  fired the hand-back; turn 6 the model explained the semantics back — "my
  fragment had no arm for missing, so it went unhandled and the session still
  holds nothing open" — then continued. The teaching message works.
- DESIGN CONSEQUENCE (the belief this section owns): under the one-invocation
  law (clean truncates to one line), a bare call to a branch-returning verb
  ALWAYS hands back — success (`ok`) included — so such verbs are inherently
  two-turn in the live flow unless the fragment handles the outcome. Design
  notes vocabulary knowing a named-branch verb's happy path also returns to
  the host. The alternative — teach the model the arm shape, or let `clean`
  preserve continuation arms — is an open knob, not yet ruled.

LANDED 2026-09-10 — the wire flip and its live witness. koru merged the
sequencing (`e2c9bfc9a`: chains, multi-item sequencing, armed define); kopium's
intake followed — `wire:clean` keeps the whole turn, `extra-lines` is retired,
and the run loops report the `?partial` branch. Canned wall cases `multiline`
+ `consumers` (22/22). Live witness (muse-spark, 9 turns, 32,996 tokens;
`challenges/harness-join/catalog/2026-09-10-multiline-turn.transcript.txt`):
turns 6 and 9 each composed TWO invocations in one reply and the bridge reported
`steps: 2/2 ran` — the composition this fragment exists to protect, running
from where it is actually used. The one-invocation law is gone from prompt,
intake, and enforcement.

What would correct this: `clean` starts preserving continuation arms (making
handled reads single-turn), or a ruling that bare `ok` should complete by
convention — either flips the two-turn consequence while the probes stay the
record of the current semantics.

MEASURED 2026-09-23 — composition survives the growth boundary. The live-define
`audit-marker-rebind` run (catalog entry same date) asked muse-spark to
redefine an invented verb so its new body files a marker line then the text —
a body that must use both params. The model emitted a CHAIN as the body:
`log = append(handle: h, text: "---") | ok q |> append(handle: q, text: m)`,
and the whole loop carried it — install, vocabulary listing, re-dispatch,
possession (the marker lands on disk between the two entries). Defined bodies
were always mechanically full flows (stored as source, re-parsed per call);
this is the first live evidence a model composes INSIDE one when the goal
requires it. The composition this fragment protects is not a turn-level
surface the define contract truncates — it reaches inside the invention.
Same run, second measurement: same-kind rebinding generalizes — append→append
succeeds exactly as speak→speak did, so the surviving kind-guard is
cross-kind mixing only, not a rule about `say` or about rebinding per se.
