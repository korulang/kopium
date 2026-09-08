---
challenge: model-sweep
kind: generator
status: standing
yields: one per-model live-wire transcript with usage table
catalog: ./catalog
family: wire
created: 2026-09-04
---

*Walker context: the 6-turn live wire (`headless/live.k`) has been replayed
8+ times across two models (deepseek ×3 stable, Muse Spark ×5 volatile) —
the recurrence that earned this generator. Each replay differs by model,
and the differences (reasoning burn, say-vs-forge, silence modes) are the
product. Cataloged transcripts become the eval data the prompt-tuning
loop drinks from.*

---

## The brief (sealed — you are the contestant)

You ARE the contestant. Do not ask which model; pick one **not already in
the catalog** — read `./catalog/` first and bring a model it hasn't seen.
That divergence is the entire metric: a replay on a cataloged model at
cataloged settings is a re-run, not a replay.

1. Set model, budget, and temperature at the `converse(model:)` call site
   in `headless/live.k`. Temperature 0 unless temperature IS your variant.
   Budget must clear worst-case thought *plus* utterance — reasoning models
   burn ~1k tokens before emitting one line; 4096 is the floor, 100k is
   the testing ceiling.
2. `cd headless && koruc live.k && ./a.out` — one session, six turns.
   Small spend is expected; multi-hour benchmarking is NOT this brief.
3. Write `catalog/<yyyy-mm-dd>-<model-flat>/transcript.md`: a header
   (model, temp, budget, date, score x/6, one-line verdict) plus the FULL
   unedited program output — the `[usage]` and `[wire-note]` lines are
   data, not noise. Never include secrets: the bearer must not appear;
   grep the file before you finish.

Done-gates (self-check, all mechanical): it compiles; all six turns
terminate with a recorded finish per turn; the transcript file exists
with header + full output; no secret strings in the file. Taste-gate:
the human reads the entry and it tells them something the catalog didn't
already say — or it is an honest duplicate and says so.
