---
type: belief
id: frag-second-vocabulary
provenance: parametricity spike 2026-09-13 — headless/ledger.kz + probe_ledger.k
ts: 2026-09-13
---

# Parametricity is real at the seam, and the holes are where it isn't

The north star — hand the runtime a `register` block and it becomes an
interpreter for that world — held on a second domain vocabulary. `ledger`
(named accounts, integer balances, no disk) derived its prompt, grammar,
enforcement, and growth from the register block alone, with no
notes-specific code anywhere: `"notes"` appears only at `create` call
sites, never inside `koru_std` or `wire.kz`.

Measured on `probe_ledger.k` (canned, zero tokens): the derived vocabulary
lists ledger's verbs with phantom signatures; `open-acct` mints, `post`
binds the observed handle, a forged `post` dies `HandleNotHeld` pre-proc,
a notes verb on the scope is `event-denied`, a `define` through `run` and
its call both work, `worth`'s `ok`/`missing` arms bind and fire. All four
derived things carried.

What did NOT carry — three seams, each named; all three now settled:

- **Branch-payload phantoms over-acquire** (hole 7, SETTLED koru
  `deb163cd8`): a consume+reissue verb whose named branches carry
  `string<acct!>` emitted one CreateSpec per branch, and the interpreter's
  acquire loop fired per spec — not per fired branch. Two `post`s booked
  three undischarged records for one handle. Fixed by scoping each spec
  to the branch that carries it; pinned by `440_022`.
- **Generated locals collide with module state** (hole 8, SETTLED koru
  `0d3d699af`): the emitted `dispatch_<scope>` used `name_len`,
  `name_buf`, `event_name` as locals in the same scope as the
  vocabulary's `var`s. Fixed by putting every implementation-only
  generated binding under `__koru_*` and self-qualifying event
  containers' `Input`/`Output`; pinned by `440_023`. Parametricity is no
  longer luck of the namespace.
- **`$mod` in a plain `fn` emits verbatim into Zig** (SETTLED koru
  `dca682df7`): host lines at both emit sites now run `rewriteModToBare`
  — the spelling interpolates to the bare decl inside the module's
  container, same rule proc bodies get. Pin `400_189` unparked.

Also observed, not yet a hole: every vocabulary re-implements
handle→resource lookup (`slotOf`/`acctOf`) and re-validates possession the
pool already enforced. That duplication is a latent vocabulary-API
question, not a bug.

The shape this gives the scene: derivation is real — a second vocabulary
is an afternoon, not a project — and every seam the spike surfaced is now
closed at the emission/interp layer, where "what the declaration says"
and "what the pool books" had diverged. Wire-as-SSR note: the bridge
*did* render every effect branch server-side here; the mis-render was
below the wire, in the bookkeeping.

What would correct this: a ruling that branch payloads may not carry
phantoms — the larger hole, since a refusal-armed verb could then never
keep possession across the refusal — or a third vocabulary surfacing a
seam class the first two could not see.
