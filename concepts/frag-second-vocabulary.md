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

What did NOT carry — three seams, each now named:

- **Branch-payload phantoms over-acquire** (hole 7): a consume+reissue
  verb whose named branches carry `string<acct!>` emits one CreateSpec per
  branch, and the interpreter's acquire loop fires per spec — not per
  fired branch. Two `post`s booked three undischarged records for one
  handle; hang-up dispatched `close-acct` per stale record and the module
  panicked on the dead slot. The resource world a successor inspects was
  lying about what was held.
- **Generated locals collide with module state** (hole 8): the emitted
  `dispatch_<scope>` uses `name_len`, `name_buf`, `event_name` as locals
  in the same scope as the vocabulary's `var`s. A module naming its own
  state `name_len` cannot register — parametric by luck of the namespace.
- **`$mod` in a plain `fn` emits verbatim into Zig** — dies as
  `expected expression, found 'invalid token'` instead of a Koru-level
  refusal naming the real constraint (only `~proc` bodies see `$mod`).

Also observed, not yet a hole: every vocabulary re-implements
handle→resource lookup (`slotOf`/`acctOf`) and re-validates possession the
pool already enforced. That duplication is a latent vocabulary-API
question, not a bug.

The shape this gives the scene: derivation is real — a second vocabulary
is an afternoon, not a project — and the remaining work is at the
emission/obligation layer, where "what the declaration says" and "what
the pool books" still diverge. Wire-as-SSR note: the bridge *did* render
every effect branch server-side here; the mis-render was below the wire,
in the bookkeeping.

What would correct this: hole 7's settler closing (post nets one record,
probe exits clean), hole 8's settler closing (a `var name_len` module
registers), or a ruling that branch payloads may not carry phantoms —
which would be the larger hole, since a refusal-armed verb could then
never keep possession across the refusal.
