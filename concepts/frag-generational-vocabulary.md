---
type: belief
id: frag-generational-vocabulary
provenance: live thread 2026-09-23 — "this was MEANT to be an implementation
  of RLM, where it can recursively improve" — locating the lost leg in code
ts: 2026-09-23
---

# The recursive loop needs heredity — and heredity needs a verdict

Kopium was always meant to be an RLM — the recursively-improving leg. The
pieces were built but never closed into a loop: the model CAN rewrite its
own vocabulary mid-session (measured live: stacking + late binding, catalog
`double-entry-armed`), but `DefinedFlows` is durable *per session* —
allocated at `bridge:create`, destroyed at deinit, serialized to nothing.
Session N+1 inherits nothing. Growth without persistence is not recursion;
it is a series of sessions with good moments.

The loop that makes recursion *improvement* rather than oscillation maps
onto the three evolutionary operators:

- **Variation** — the model itself. Every session invents freely; scenario
  steering steers the mutation operator.
- **Heredity** — the missing piece. Persist the defined-flows table across
  sessions (a vocabulary file per scope, loaded at bridge create) and
  session N's inventions become session N+1's starting genome. One seam,
  koru-side; the derivation machinery (vocab → prompt) already exists, so
  inherited verbs surface in the prompt for free.
- **Selection** — the oracle layer (`frag-oracle-coverage`). Episode
  verdicts score which definitions earned their keep; only definitions
  from passing sessions inherit. A bad verb variant cannot fossilize into
  the genome because it never passed a gate. *This is why measurement and
  recursion are the same work*: the oracle is the fitness function.

The domain that makes all three real is koru-libs: its suite board is a
mechanical oracle over *work that matters* — packages are instruments that
exercise the compiler, so an agent greening the board is the toolchain
improving itself through its own consumer. The genotype is an inspectable
`.kz` vocabulary file you can read, diff, and garden — recursive
self-improvement where the artifact under selection is a program you can
hold.

Open edges: the vocabulary file's provenance fields (defined-by,
earned-on, use-count); name collisions across generations (redefine
already rules it — last write wins, which is correct); staleness against
scope changes (a persisted verb that calls a renamed event should refuse
loudly, and the refusal taxonomy already has the slot); and whether
promotion is auto (all green-session definitions inherit), taste-gated
(human promotes), or oracle-gated (per-verb episode evidence). The
oracle-gated shape is the interesting one — a verb earns inheritance the
way a test earns a pin.
