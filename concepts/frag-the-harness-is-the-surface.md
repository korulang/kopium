---
type: belief
id: frag-the-harness-is-the-surface
provenance: kopium bench + can-kopium-compete draft, 2026-10-06 — the post
  claimed "kopium is not a harness" while every measured number was a
  harness number; Lars called the disconnect, and the correction is a
  belief change, not a wording fix
ts: 2026-10-06
tags: [kopium, harness, wire, charter, frame]
---

# The harness is the surface — kopium is a derived harness (belief)

**Kopium is a harness.** A marshal, an agent loop, a wire protocol, a
model behind all of it — the same seat stock's `LLMAgent` occupies. The
claim that survives measurement is not "a different architecture," it is
"the same seat, derived": the tool surface (grammar, prompt, capability
enforcement, vocabulary growth) renders from the `register` block where
stock handwrites it per domain. The 50-task board measured exactly that —
a derived harness vs a handwritten one — and every number in it (calls,
flips, rejects, billed cost) is a harness number.

**The wire is not beneath the interpreter — it is the surface.** The
charter's rule "the marshal may never justify a surface decision" guarded
against leakage: benchmark shapes reaching the model. It was silently
overextended into "the marshal cannot justify semantics," which is false
and was violated correctly on 2026-10-06: non-blocking `say` changed what
say *means* (emit + own its text; the turn composes) because the harness's
one-inbound-per-outbound contract exposed that a blocking read was wrong
wire semantics — not merely wrong transport. Harness economics found the
defect; the wire's own reasons justify the fix. The restated rule:
benchmark *shapes* must never leak upward; harness *economics* finding a
defect is the instrument working.

**Why "not a harness" was the misfire, not the truth.** The site's own
doctrine — `the-harness-is-the-product`, `the-harness-is-the-spec` —
holds that the harness is where constraints live and the product is what
survives it. A derived harness is the strongest claim in that vocabulary:
the constraint surface generated from the world it constrains. Reaching
for a "runtime" prestige category instead was capture in the opposite
direction — defining the project against the benchmark rather than from
its own doctrine. Related: frag-only-tool-is-the-interpreter holds about
what the *agent* lives inside; this fragment is about what the *artifact*
is. The agent's frame law and the artifact's category are different
questions, and conflating them produced the sentence.

---

## Evolve 2026-10-11 — the surface got an envelope and a ceiling

Two model-filed surface defects closed at the kopium layer (commissioned
to an independent fixer — codex — audited by a second agent, landed here):

- **Inbound envelope.** Human prose now arrives wrapped `user: <text>`
  via `observe-human` — distinct from the harness's own step/residue/
  error reports, which share the same `role: "user"` observations. The
  model had self-diagnosed this ("r32 is my own previous reply").
- **Items-per-turn cap.** `run-capped` counts turn items with a
  kopium-side mirror of the bridge segmenter and rejects over 128 as
  `exhausted`, with `last_event` surfaced to the model. The mirror was
  proven exact against `partial.total` on a differential harness
  (bench/scratch-itemcap.k), including the 150-item storm shape.

**The technique, not just the fix:** a harness-layer cap is honest only
if its count agrees with the enforcer's — the audit measured a real
±1-per-define divergence before the verbatim port, and the differential
harness is the durable instrument for keeping them in lock. One drift
hole stands open: a new `?`-optional branch on `std/bridge:run` would
drop silently through `run-capped`'s hand-mirrored union — mandatory
branches refuse at compile, optional ones don't.
