---
type: belief
id: frag-parents-compile-descendants
provenance: reconstructed 2026-10-20 — Lars remembered a <15h-old discussion
  whose transcript died unwritten in the Mac crash; recovered to
  artifact-level from git (`3cf6f3d`, `482fa22`, the `world/agent/` name)
  plus his correction of the drifted summary: children are *regenerated*,
  and they share the bridge under a parent that can look at it
ts: 2026-10-20
---

# Sub-agents are authored and compiled by the parent — not self-rewritten

`frag-generational-vocabulary` records growth as a session redefining its
own flows — `define` mutates the running agent, `gate.kz` decides what
fossilizes, `world/` carries the genome to session N+1. The direction Lars
was excited about is the inversion of that axis: **a sub-agent does not
grow by rewriting itself. The parent regenerates it.** The parent authors
a module (its own `register` — the child's derived vocabulary), invokes
`koruc`, and summons a fresh agent. Children are replaced, not edited;
selection and mutation live one tier up, where the receipt can name what
changed.

Why this is the better shape, and not just a preference: an agent editing
itself mid-flight has no oracle boundary — nothing can answer "what changed
you." A compiled descendant *is* the artifact: readable before it ever
runs, diffable against its parent, gated by the same replay receipts
`gate.kz` already applies to staged defines, and disposable without
sentiment. `world/agent/` vs `world/lib/` (recorded 2026-10-18) was already
the address: dumb flows inherit as files; smart descendants are
regenerated as programs.

Lars's refinement, his words: children **share the resource bridge**, and
the parent can **look at it** — the bridge is a shared custody surface
across agents, with the parent holding inspection rights, not each agent
owning a private one.

What the recon found standing — the substrate is further along than the
idea's absence implies:

- `std/cell` is already an in-process descendant: `open(shape, id:,
  scope:, world:)` mints a session with its own bridge and the caller's
  obligation, `run` dispatches a turn into it, `hibernate` discharges.
  Scope and world are *parameters* — a cell is an agent-shaped session on
  a shared world, today.
- `std/fleet` is the custodian Lars described wanting later: it owns every
  spawned cell's obligation (evict/retire/drain are the only discharge
  paths), and `std/fleet(node[id])` hands the parent a *borrow* — enough
  to run and inspect, never to mint or drop. "Children share the bridge,
  parent can look" is the fleet's existing contract, not new machinery.
- What is genuinely missing for the *compiled* descendant: koru_std has no
  runtime process-spawn verb (`deps.command` is comptime commands; kernel
  `spawn` is threads). `commander` (built in koru-libs the same day, on
  `std/args`) is the child binary's argv side — a summoned binary takes
  its briefing as arguments.

The live question Lars named: **can we even easily create agents this
way?** That is a probe, not a plan — the smallest experiment is a parent
program that writes a child module, shells `koruc`, and observes what
refuses. In-process `fleet` cells answer the shared-bridge half without
needing process spawn at all; the two halves are independently testable.

Open edges: whether `summon` is a vocabulary verb, runtime machinery, or
just a program shape; in-process cell vs out-of-process binary (the cell
path can't carry a *new* compiled vocabulary — a scope is comptime — so
true regeneration still wants a compile step); what "parent looks at the
bridge" means as a verb (fleet borrows answer inspection of cells, not yet
of custody); whether a child's world/ inherits `holds.log` custody across
process boundaries or only through the parent's session.

2026-10-20 — **the in-process half answered: yes.** `headless/probe_cells.k`
(a ~60-line program over `std/fleet` + `std/cell` + `app/db_scope`) spawned
a `db`-scoped cell, ran two turns into it, and read its custody afterward.
What the run measured, not designed:

- The child's bridge holds custody across `cell:run` calls — `conn: r1`
  minted on turn one resolved on turn two.
- "Share the resource bridge" concretizes to a *shared world root with
  per-child slices*: `cells/child-1/holds.log` recorded the child's whole
  custody arc (session-open, mint, release) and the parent read it through
  `std/fs:read-lines` — inspection is ordinary file access, not a verb.
- `fleet:drain` discharged the resident through the custody path; the
  borrow is all the parent ever held.

What this does *not* answer: a model in front of `cell:run` (the wire
machinery from `live_db.k` points at `cell:run` instead of `bridge:run` —
plumbing, not architecture), and the out-of-process half (authored module
→ `koruc` → spawned binary) still wants the runtime spawn verb koru_std
does not have. The probe also surfaced that "the bridge" was never one
object: each cell's bridge is its own; what is shared is the world root
and the custody record's legibility to the parent.
