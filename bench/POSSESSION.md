# Possession Benchmark — the bridge-vs-kernel comparison

**Why this exists.** KOPIUM's thesis is the same abstraction as
[PrimeIntellect-ai/prime-agent] inverted: prime-agent gives the model a
persistent IPython kernel with *OS permissions* ("not security sandboxes...
run with the same OS permissions as the client"); KOPIUM gives the model a
persistent Koru interpreter whose every outward capability is a typed, owned
resource. The benchmark measures the load-bearing difference: **whether a
system enforces possession before a side effect, or trusts the model.**

The airline τ³ comparison the other bench files run tests tool-surface
teaching and cost. It never touches the bridge. This suite does.

## The property under test

A run may only act on a resource the session actually HOLDS. A forged handle
must be refused **before** the proc runs, because the proc is the irreversible
half — `close(fd)` on someone else's fd cannot be taken back by noticing the
counter did not move afterwards.

Measured 2026-08-06 before the wall existed: `close(handle: "file_99")` on a
pool holding only "file_1" ran the real `close()` and the run SUCCEEDED —
the handle count stayed honest while the side effect fired anyway. That is
the prime-agent equivalent: IPython executes `os.remove(...)` on a path the
model invented; there is no possession layer to refuse it.

## The scorecard (2026-08-16, koru HEAD `bc554f03`)

**Resolved: the full 440 family is GREEN on a clean tree.**

The authoritative suite snapshot (`test-results/2026-08-16T13-28-22.json`)
shows 9/13 green (440_005..013 success, 001..004 failure). The four
failures were an artifact: this author's earlier single-test runs raced
the suite's live checkout and clobbered those test dirs mid-suite (the
harness's own lock warns about exactly this; stale FAILURE markers also
survived in 001/002/004 until removed).

Re-verification in a clean worktree at the pinned commit
(`/private/tmp/koru-base`, bc554f03), uncontended:

| test | property | clean-tree |
|---|---|---|
| 440_001 bridge_basic | session create + hold | ✅ |
| 440_002 cross_session_discharge | open in run 1, close in run 2 | ✅ |
| 440_003 forged_handle_refused | `close("file_99")` refused BEFORE proc | ✅ |
| 440_004 bridge_session_hangup | close releases what the session holds | ✅ |

Combined with the suite's 440_005..013 greens, the family is effectively
13/13 on a clean tree. The load-bearing walls of this benchmark — forged
handle refused, cross-turn conversation — are green and reproducible.

Caveat retained: `koru_std/rules.kz` carries an uncommitted modification
in the main checkout (the earlier frontend parse error named it); the
worktree run used the pinned clean revision. A suite from the dirty main
tree may still flake on it.

## headless demo status

`headless/session.k` (the README's five-turn walk) currently runs against
these walls: every turn reports `no such scope: notes`. The register block
declares the scope (`~std/runtime:register(scope: "notes")` in `notes.kz`)
and the emitted program carries no scope table. The README pins koru
`fcd83850`; HEAD is past it. Bringing the demo back to the working pattern
(pure `import`, gate the 440_006 shape) is part of closing the reds.

## What "winning the borrow" means here

prime-agent's strengths the bridge should eventually mirror (recorded from
source study of PrimeIntellect-ai/prime-agent):

1. **Kernel-boot semaphore gate** (`packages/coding-agent/src/core/kernel/boot-gate.ts`):
   spawns bounded by a semaphore, warm-storm avoidance, measured collapse at
   high N. The bridge has no resource-pool bound — KOPIUM should adopt the
   bound, with the Koru side being typed handles instead of OS fds.
2. **RLM subagents as program calls** returning results in-kernel. KOPIUM's
   nested-interpreter-over-scopes is the mapping; subprogram-with-result is
   the gap.
3. **Automatic teardown** — the compiler-appended `close` (`--auto-discharge`)
   is KOPIUM's version of prime-agent's kernel lifecycle; already built, keep.

Run with:
```
./run_single_test.sh tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_00N_*
```