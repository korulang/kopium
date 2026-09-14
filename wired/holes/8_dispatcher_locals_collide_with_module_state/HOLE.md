# Hole 8 — generated dispatchers emit local names that collide with module state

**Found:** 2026-09-13, same spike. `headless/ledger.kz` declared
`var name_len: [MAX_ACCTS]usize` and the emitted `dispatch_ledger` failed
the backend build with `local variable shadows declaration of 'name_len'`.
**Confidence it's real:** 100% (reproduced; fix was renaming my own state).

## What it looks like

The registry codegen emits, per scope, a `dispatch_<scope>` fn whose locals
are plain words — `name_buf`, `name_len`, `event_name` — in the same
module scope as the vocabulary author's `var`s. A module that names a
piece of state `name_len` cannot register: the derived code does not
compile. `notes.kz` never hit it because its state is named
`handle_len`/`content_buf` — a collision the first vocabulary happened not
to trip, i.e. the derivation looked parametric partly by luck of the
namespace.

## Why it is worth a hole of its own

"Hand the runtime a register block and it becomes an interpreter for that
world" requires the vocabulary author to name their own state freely. A
hidden reserved-word list — discoverable only by tripping it — is the
derivation lying about what it owns. The author's module and the generated
dispatcher are different scopes of authorship; the generated code should
never lose a name fight to user code.

## The want

Generated locals use names user code cannot collide with (`__k_name_len`,
the `__k*` convention the emitters already use for temporaries) — or the
dispatcher is generated into a scope where module vars are out of reach.
Either way the vocabulary author never sees a shadow error naming the
derived code's internals.

Sibling observation, same emission-honesty family (not separately holed):
`$mod.` inside a plain `fn` (it rewrites only in `~proc` bodies) emits
verbatim into the Zig and dies as `expected expression, found 'invalid
token'` — a refusal that should name itself at the Koru level.

## Repro / settler

```bash
sh wired/holes/8_dispatcher_locals_collide_with_module_state/settler.sh
# exit 0 = hole OPEN (module with `var name_len` cannot register a scope)
# exit 1 = hole CLOSED (the same module compiles and runs)
```

## Verdict — CLOSED 2026-09-14

Settled koru-side in `0d3d699af` ("emit: generated dispatcher bindings
carry the __koru_ namespace"). Every implementation-only binding the
registry emits — locals, params, and the module-level decls
(`ScopeEvent`, `FieldValue`, `getArg`, `buildInput`, `dispatcher_std`)
— now spells `__koru_*`, which Koru source cannot name; the protocol
surface (`dispatch_<scope>`, `scope_events_<scope>`, pub aliases) keeps
its conventional names. Event-container signatures self-qualify
(`@This().Input`/`@This().Output`) so a user `const Input` can't make a
sibling reference ambiguous. The settler also surfaced a second bug in
the same fix: register-helper dedupe was keyed on the callee's
qualifier (`std.runtime`), so a merged `.k`/`.kz` companion's second
transform copy suppressed the first's helpers — the key is now the
site's home items list (`Helpers.siteHomeModule`). Pinned by koru
regression `440_023_dispatcher_locals_never_shadow_module_state`;
settler reports CLOSED (exit 1 is the recorded convention, not a
failure).
