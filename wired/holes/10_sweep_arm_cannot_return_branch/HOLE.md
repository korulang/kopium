# Hole 10 — `=>` on a void effect died in emitted Zig, undiagnosed

**Found:** 2026-09-28, re-attempting direct `| ran | rejected` returns out
of `bench/tau-agent.k`'s `drive`.
**Resolved same day:** the program was ill-formed all along — `=>`
constructs a branch of the handled effect's resume sum, and a void effect
(`! beat <payload>`, no `-> T`, no named arms) has nothing to construct.
The real defect was the MISSING DIAGNOSTIC: the construct sailed through
shape checking and died in emitted Zig.

## What it looked like

```
output_emitted.zig:238:31: error: type 'void' does not support struct
    initialization syntax
        return .{ .ran = .{ } };
output_emitted.zig:102:66: error: function with non-void return type
    'output_emitted.main_module.work_event.Output' implicitly returns
```

## The fix (in koru)

`src/shape_checker.zig` now walls it at the existing glyph-discipline site
(400_122 `-> T` / 400_126 unknown-arm siblings), pinned by
**400_199_reject_construct_glyph_on_void_effect**:

```
error[KORU102]: `=>` inside `! beat` resumes the effect `beat`, but it
declares no resume value or arms — there is nothing to construct.
Branches of the enclosing flow come from the call's own branches
(e.g. `| done => ...`); a value the handler hands back needs resume arms
on the effect (`! beat T | a | b`)
```

`probe.k` in this directory now fails with that diagnostic.

## The sweep-arm gap — FIXED 2026-10-03

This hole's ORIGINAL surface — `=>` inside a `! query` sweep arm
(`std/store:query`) — leaked raw Zig because the query transform grafts the
user arm body into the synthesized sweepbody flow and marks the graft
`is_transformed_subtree`; `shape_checker`'s continuation walk skips marked
subtrees entirely. The arm body was simply never walked.

**Fix:** the wall lives in the store transforms, pre-graft, while the user
body is still visible. `refuseUncrossable` (`koru_std/store.uncrossable.kz`,
beside the `Graft` struct it guards) walks the arm's continuation tree for
`.branch_constructor` nodes (`=>` and bare-return `->` share the tag) —
nested inside conditionals/foreach/switch as well as at the top level — and
refuses `KORU102` before any graft:

```
error[KORU102]: std/store:query(box): `=>` inside a `! query` arm has
nothing to construct — the arm body grafts into a void synthesized unit,
so a branch of the enclosing tor cannot be produced from in there. Hand
the verdict out through the store (or module state) and branch after the
call returns.
```

Walled families, all sharing the one helper:

| transform | arms walled | pin |
|---|---|---|
| `std/store:query` / `first` | `! query`, `! first` | `690_357` |
| `std/store:new` interceptors | `! inserted/removed/updated/cleared/discharge` | `690_358` |
| `std/store:watch` (both collection paths) | `! <field>` | `690_359` |
| `std/store:rule` / `preorder` | `! row`, `! preorder` | `690_360` |

Deliberately exempt: `! step` / `! wait` arms — a pump participant's `=>`
constructs its own declared verdicts, which is how it answers the pump
(`step_terminal_branches`; control `690_309` stays green). `@label` needs
no new wall — unknown labels already refuse `KORU041` pre-graft.

`probe.k` in this directory now fails with the KORU102 diagnostic above,
pointed at line 21 — a compiler refusal (exit 1), not a Zig-codegen error.
(Emission artifacts still get written before the refusal propagates; what
the pin asserts is the diagnostic's presence, not the pipeline order.)

## Workaround in use (unchanged)

Verdict crosses the sweep boundary as module state (`count-out` /
`count-rejection` set `verdict_ran`; `verdict()` reads it) — same pattern
as `saw-eof`/`take-pending`.
