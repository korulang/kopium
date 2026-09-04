# Hole 5 — full backend builds rewrite `build.zig.zon`'s fingerprint

**Found:** 2026-09-04, landing a day of headless work (five reverts and
counting).
**Confidence it's real:** ~70% (three distinct committed values plus a
clean negative control; the remaining 30% is "zig normalization working
as intended," which the non-convergence argues against — see below).

## What it looks like

`headless/build.zig.zon` carries `.fingerprint`, and full `koruc`
backend builds rewrite it while cached builds leave it alone:

```
base:     .fingerprint = 0x9aa61d90bb082983,
b1:       .fingerprint = 0x9aa61d90bb082983,   # cached probe build
b2:       .fingerprint = 0x9aa61d90bb082983,   # cached probe build
```

versus across sessions with full builds (`live.k`, `headed.k`,
`session.k`):

```
0x9aa61d9092511e9f → 0x9aa61d90bb082983 → 0x9aa61d90b272106e
```

Three values, same dependency URL and hash throughout. A build with no
source changes leaves `git status` dirty — every session pays a manual
`git checkout -- build.zig.zon`, and the one time nobody reverts, the
churn ships as a commit that means nothing.

## Why it is worth a hole of its own

If this is zig's own manifest normalization, the fix is to commit
whatever it converges to — but it does **not** converge: identical
inputs produce distinct fingerprints per full build, which smells
nondeterministic (a timestamp, a hash seed, a regenerated random) rather
than canonical. Nondeterministic source rewrites break the only
contract that matters here: *same sources in, same tree out*. And the
failure compounds silently — the diff is one hex literal, the kind of
line that slides into a commit unreviewed, which is exactly how the
`bb082983` value got committed in the first place.

## This is koru-side

The rewriter is the `koruc` driver and/or zig itself; kopium can repro
and pin, not fix. Per the one law, the fix lands in
`/Users/larsde/src/koru` with the regression pinned first — this file
is the repro half of that.

## The want

A full build with no source changes leaves `git status` clean. (Deliberately
not prescribing *how*: deterministic fingerprint, driver stops touching
the zon, or the field documented as volatile — that is the koru-side
call. A kopium-side hook auto-reverting it would mask real manifest
changes and is refused in advance.)

## Repro

```bash
cd headless
git checkout -- build.zig.zon
grep fingerprint build.zig.zon          # record value A
koruc live.k >/dev/null 2>&1           # full backend build
grep fingerprint build.zig.zon          # value B != A
koruc probe_vocab.k >/dev/null 2>&1    # cached build
koruc probe_vocab.k >/dev/null 2>&1    # cached build
grep fingerprint build.zig.zon          # still B — churn is full-build-only
git checkout -- build.zig.zon; rm -f a.out
```
