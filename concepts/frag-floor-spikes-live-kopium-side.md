---
type: belief
id: frag-floor-spikes-live-kopium-side
provenance: 2026-10-03 design ruling — after the depth-cap fix, Lars
  asked where the floor primitives the interpreter's Zig hides should
  live, and ruled: a small kopium thing, not std
ts: 2026-10-03
---

# The interpreter floor is spiked kopium-side, spelled for promotion

The vocabulary floor — a session map, env introspection, reparse — is
plumbing the agent's surface needs and koru_std does not yet have. The
ruling for where it gets built:

- **Implementations live in kopium `app/` modules**, where a measured-
  naive implementation is legal. A 32-slot linear-scan map is correct
  for a session that stashes dozens of keys, and it would never survive
  the std gate's optimality bar. Naive is not a dodge here — it is the
  honest fit between implementation cost and measured workload.
- **Spellings are chosen as if the verbs were already std candidates.**
  The module header says so on purpose: the day std grows the real
  floor, the kopium version is the measurement that says what it must
  do — not a second vocabulary to migrate off.
- **Enforcement never moves.** The governor half of the depth-cap work
  (`defined_depth`, possession checks) stays below the grammar in
  koru_std — a cap reachable from agent-vocabulary space is a cap that
  can be reset. What moves is the plumbing, never the kernel.

The first instance is `headless/mem.kz` (`stash`/`recall`/`forget`/`keys`,
no obligations — `full`/`missing`/`too-large` are named outcomes, not
refusals), wired into the live agent through a composite `kopium` scope
(`scope(notes)` + `scope(mem)`) in `live.k`. `probe_mem.k` is the
zero-token verification.

The spike did what kopium spikes are for: it surfaced a compiler gap as
the deliverable. `scope(other)` composition silently resolved nothing
when the referenced register had already transformed — the composite
scope minted empty and every verb through it was denied. Fixed in koru
(`ea4d2a75e`, pin `430_068`), not worked around here.

The open question this frames: each floor verb is one more candidate
for the std floor, and the composite scope is where vocabularies stop
being whole-domain and start being *assembled*. If a third kopium
domain wants the map too, the `kopium` register is already the place it
joins — composition is the assembly layer.
