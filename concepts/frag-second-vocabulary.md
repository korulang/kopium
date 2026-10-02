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

2026-09-14: the enforcement leg deepened. Field-membership — "a named
field the verb never declared is `validation-error` at dispatch" — now
exists (koru `b4742ff96`, pin `440_025`), and crucially it is *derived*:
`validateFlow` judges provided fields against the scope's own
`get_event_input` table, the same registry data the prompt and dispatcher
are emitted from. No vocabulary-specific check was written; `ledger`'s
verbs get field refusal for free, as will the third vocabulary. The
masquerade's subset boundary is now enforced by the register's own data —
the first enforcement mechanism that is genuinely parametric rather than
hand-maintained per vocabulary.

2026-09-16: the bound-reference leg closed, and with it the bridge-mirror
catalogue is empty — every measured cell is `supported` or
`refused-honest`. An unbound identifier no longer degrades to its own
text (koru `15d8745ab`, pin `440_026`): the wire parser refuses bare
values at item heads, and the flow's validation walks each arm path
with a bound set, refusing `validation-error` that names the binding
instead of `HandleNotHeld` blaming a handle. Nothing in the check names
`notes` or `ledger` — it is scope discipline, uniform across registers.
The masquerade's three boundaries — what parses, what the wire admits,
what the interpreter honours — now coincide on every measured cell.

2026-09-16, third vocabulary `calc` (no handles — the seam class the
handle vocabularies could not see): the derivation held. Payload
bindings, refusal branches without possession, bound-reference and
field-membership refusals, the vocabulary wall, per-scope growth — all
carried free of hand-work. But the probe surfaced the first seam in the
derived surface itself, not the runtime: the wire grammar's worked
example was hardcoded notes (`open`/`append`, "the handle the call just
issued"), taught verbatim on a scope where both verbs are `event-denied`
and nothing mints a handle. The vocabulary list was derived; the example
was not — hole 9. The finding reframed the claim: derivation must reach
*inside* the prompt's prose, not only the manifest it appends.

Hole 9 settled the same day (koru `d7e6d3b0c`), and settled by
derivation, not deletion: `scope-grammar` synthesizes the worked example
from the scope's own manifest — the head is the first verb that provably
hands a value to an arm, the chain target is the possession edge when
one exists (`open`→`append` on notes, reproduced from data), else the
lightest sink that can carry the binding (`add | sum v |> say` on calc).
The frontier the probe found is gone: every domain byte in the prompt is
now drawn from the table that judges the model's output.

The shape this gives the scene: derivation is real — a second vocabulary
is an afternoon, not a project — and every seam the spike surfaced is now
closed: at the emission/interp layer, where "what the declaration says"
and "what the pool books" had diverged, and at the prompt layer, where
the last fixed cast is now synthesized from the manifest. Wire-as-SSR
note: the bridge *did* render every effect branch server-side here; the
mis-render was below the wire, in the bookkeeping.

2026-10-03, parametricity reached the register's *authorship*: the
airline scope — 14 verbs transliterated from tau2's live schema — is
generated by Koru itself (`bench/gen_airline.kz` reads
`airline_schema.json`, decides every field type, emits the tors, the
vocab doc, the JSON serializers, the `say` voice). Python's share shrank
to `dump_airline_schema.py` — a marshal that dumps the external schema
and decides nothing. The type mapping is the wire grammar's own ruling:
scalar fields stay `string`/`i64`/`f64`/`bool`, composite JSON fields
declare `Source`, `calculate.expression` declares `Expression` — the
same types the wire gate now admits bare. What the spike could not yet
say: which parts of a vocabulary are *derivable* and which are the
experiment. The answer landed as a file boundary — `airline_tools.kz`
is regenerated on every schema drift, `airline_native.kz` stays
hand-written because its phantom obligations ARE the thing being
measured. Generation is parametric; possession semantics are authored.

What would correct this: a ruling that branch payloads may not carry
phantoms — the larger hole, since a refusal-armed verb could then never
keep possession across the refusal — or a third vocabulary surfacing a
seam class the first two could not see.
