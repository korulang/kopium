# Hole 2 — the point-free choke replicates onto stages that don't declare it

**Found:** 2026-08-01, asking why `d_turns.k`'s delta ladder still carries two
byte-identical `| not-found |> koru/yyjson:close(doc)` lines.
**Confidence it's real:** ~90% (red/green pair here differ in ONE variable —
branch *names* — and the located code path is a two-line asymmetry).

## The question that found it

`d_turns.k:100-104` is the `analysis` pyramid from *A Pyramid Is a Pipeline,
Hand-Unrolled* — six checks deep, re-raising the same handler by hand:

```koru
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> …
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)   ← identical
            | not-found |> koru/yyjson:close(doc)       ← identical
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)               ← identical
| err _ |> _
```

Deleting the two inner `| not-found` lines and letting the outermost one choke
the whole block gives `KORU022: branch 'not-found' must be handled` ×2. That
part is *correct and not the hole* — the choke is a rule of the **point-free
chain surface**, and this ladder is a hand-written explicit pyramid of named
arms. There is no chain here for the desugar to see, so nothing replicates.

The hole is what happens when you *do* write it point-free.

## The hole

`input.kz` is that ladder in point-free form — a `doc` carried at every stage,
per-stage extra args (`key:`, `index:`), the survivor threading into each
stage's single open `v:` field, and three dedented chokes because the stages
declare three different unclaimed branches:

```koru
~ladder = obj.get(doc, v: r, key: "choices")
  |> arr.get(doc, index: 0)
  |> obj.get(doc, key: "delta")
  |> as.string(doc)
| not-found => gone
| out-of-range => gone
| wrong-type => gone
```

The chain **desugars** — survivor resolution is per-stage and correct. But the
replication isn't, and it dies eight times over:

    error[KORU021]: event 'obj.get' has no branch 'out-of-range' (available: found, not-found)
    error[KORU021]: event 'obj.get' has no branch 'wrong-type'   (available: found, not-found)
    error[KORU021]: event 'arr.get' has no branch 'not-found'    (available: found, out-of-range)
    error[KORU021]: event 'as.string' has no branch 'not-found'  (available: ok, wrong-type)
    … (8 total — every choke × every stage that doesn't declare it)

`control.kz` is the same file with the stages' branch names made uniform
(`| gone` everywhere) — **identical shape, one variable changed** — and it
builds and prints `got hello`. So the blocker is not the carried `doc`, not
the extra args, not the type-threaded slot, not chain depth. It is purely that
the ladder is **heterogeneous**.

## Why (located)

`src/ast_transform.zig` treats the claim set two different ways:

- `soleSurvivor` (:747) matches claims to a stage **by name**, skipping any the
  stage doesn't declare. That's why every stage here still resolves exactly one
  survivor and the chain desugars at all.
- `levelContinuations` (:863) then clones **every** choke onto **every** level
  with no such filter — `allocator.alloc(1 + chokes.len)` and copy. Dead arms
  land on stages that never declare them, and the downstream coverage checker
  correctly rejects them as KORU021.

The blog's exactness rule — "a mistyped `faild` is caught as a dead claim
rather than a real `failed` going quietly unhandled" — is aimed at the *chain*
level: a claim naming a branch **no stage** declares. Applied per-stage it
over-fires, because in a heterogeneous ladder `| not-found` is a live claim at
stages 1 and 3 and a dead one at stage 2 by construction.

## The want

Filter chokes per stage on replication, the same way `soleSurvivor` already
filters them on survivor resolution: a stage gets the chokes it declares.
Keep the exactness wall, but raise it to the chain — a choke matching **no**
stage is the typo, and that's the one worth a diagnostic.

That would make the blog's claim true of real code, not just uniform-branch
code. The compiler's own `analysis` pass is homogeneous (`| failed` at every
rung), which is why the feature shipped without this surfacing — and
`koru-libs` result ladders are heterogeneous almost by nature: `not-found` /
`out-of-range` / `wrong-type` is a *good* API, and it is exactly the shape the
collapse can't reach.

## Repro

    koruc build input.kz     # 8× KORU021 — dead claims replicated onto every stage
    koruc build control.kz   # builds; ./a.out prints "got hello"
