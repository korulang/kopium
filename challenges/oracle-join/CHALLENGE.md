---
challenge: oracle-join
kind: generator
status: standing
yields: one new oracle-backed case on the harness wall
catalog: ./catalog
family: harness
created: 2026-09-05
---

*Walker context: some bars cannot co-evolve with the implementation —
FrontierHarness Eval v1 (pinned in `bench/frontier/MANIFEST.md`), Exo's
mechanisms (pattern provenance, code never vendored). The bespoke
`frontier-001` commission proved the shape: borrow one oracle property,
re-express it on our seam, land a wall case with provenance. Every
"the outside world measures X" talk that does not add a case re-derives
the gap. This generator grows the oracle-backed wall.*

*Siblings stay independent. `harness-join` grows joins between the bridge
and the τ³ path; `model-sweep` grows six-turn wire transcripts. This brief
drinks those catalogs and `bench/frontier/MANIFEST.md` as *facts on disk*;
it does not replay them.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Do not ask which property to borrow. Read
`./catalog/`, `bench/harness-check.py`, and `bench/frontier/MANIFEST.md`
first. Pick one oracle property that is **not already a case on the
wall** — one task/verifier flavor from the pinned bar (a FrontierHarness
task, a BFCL category, a Harness-Bench protocol, a cordis pin) or one
mechanism pattern (Exo's snapshot/rewind, fork, experiment history),
re-expressed on our seam, never vendored. Variance is the metric. A
replay that re-runs the outside bar without landing a case is a re-run,
not a replay.

A property is closed when it holds on the bench path **and** is a named
case in `bench/harness-check.py` **with provenance** — source repo plus
pinned commit plus task id plus closer plus date — in the manifest's
borrowed-cases table and the catalog card here. No mystery cases.

Not in-family: a full Runta campaign, vendored task code/images/verifiers, a prose-only card, a probe
that is not wired into the wall, a case without provenance, a consumer dodge of a koru hole.
Docker-gated or API-key runs are allowed ONLY where the oracle's own closer demands them —
then Docker must also exercise our install story (a red is our bug or our install lying),
keys stay out of the repo, and spend stays micro unless the walk authorizes more.

1. Name the property in one sentence that can be wrong.
2. Close it in `bench/` — smallest wall, Docker-free, zero new deps,
   zero keys. Ask before spending model tokens; a property that can be
   proven with a canned line or a probe must be.
3. Add the case to `bench/harness-check.py`. Add the manifest row.
   Append `catalog/<yyyy-mm-dd>-<property-slug>.md`: the one-sentence
   property, what you ran (wall + new probe, exit codes), the
   provenance, the observation that would `correct` the card.

Done-gates (mechanical): the property is in running code, not a
comment; it is a case on the wall; the catalog file exists; the
manifest row exists; the wall is green with the new case; no secrets
in the card. Taste-gate: the human can point at the oracle property
and the local case in one look.
