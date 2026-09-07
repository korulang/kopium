# Hole 6 — stdlib can write a file but cannot refuse to create one, nor gate on a match

**Found:** 2026-09-07, forcing the `edit` verb (vulcan-forcing replay:
go-stack-pop-bug needs file-edit).
**Confidence it's real:** ~90% (settler below is mechanical, zero tokens).

## What it looks like

The only stdlib file-write tor is `std/fs:write { path, content }`
(`koru/koru_std/fs.kz:77`) with exactly two arms: `| written` and
`| failed string`. Point it at a path that does not exist and it CREATES
the file and returns `written` — there is no `exists`/`refused` arm, no
existing-only mode. It is whole-content create-or-truncate with no bound
and no match gating: nothing in the stdlib expresses "replace this needle
iff it occurs exactly once" or "refuse files past N bytes".

## Why it is worth a hole of its own

A bridge mutation verb needs three refusals the stdlib cannot spell:
not-found-must-not-create, mismatch/ambiguous-must-not-write, and a loud
size bound. `std/fs:write` fails all three by construction (createFile,
writeAll-as-given, no cap), so a mutating verb cannot be BUILT on it —
the refusal shapes have to live in the verb's own Zig, as `edit` does
(openFile read phase → exactly-once count → truncate-write, `-> void`).
The `-> void` half is honest against existing surface (`fs:write` takes a
borrowed slice; the file owns the bytes after `written` — same possession
shape as `edit`, nothing to discharge). The refusal half stands on this
hole, not on surface.

Contrast the read side, which needed no hole: `std/io:read-file`'s
`not-found` arm (live.k leans on it) is exactly the absence shape `read`
and `edit`-phase-1 mirror.

## The want

A refusal-shaped file-mutation surface in the stdlib — e.g. an
existing-only write, a match-gated splice, or documented refusal arms on
`fs:write` — or a ruling that transcript-channel Zig-side splices are the
sanctioned shape for bridge verbs. Today neither holds: the gap is silent.

## Repro / settler

```bash
sh wired/holes/6_fs_write_cannot_refuse_creation_or_gate_on_match/settler.sh
# exit 0 = hole OPEN (missing file created, arm `written`)
# exit 1 = hole CLOSED (write refused — re-pin the verb onto the new arm)
```

## Verdict — OPEN 2026-09-07

Settler ran (local koruc build, no network, no model):

```
HOLE 6 OPEN: std/fs:write created the missing file (arm written, no refusal)
```

`edit` lands ON this hole: its write half reimplements createFile-writeAll
with the refusal shapes the stdlib lacks, and this report is the pin it
stands on.
