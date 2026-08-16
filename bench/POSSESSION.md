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

## The scorecard (2026-08-16, koru HEAD `0c2538dd`)

**Resolved: the full 440 family is GREEN — 16/16 on a clean tree.**

The authoritative suite snapshot (`test-results/2026-08-16T13-28-22.json`)
shows 9/13 green, but that predates the gauntlet rungs that landed after
it. Re-verified by both a worktree run and a live full-cluster sweep at
the current HEAD, uncontended:

| test | property | clean-tree |
|---|---|---|
| 440_001 bridge_basic | session create + hold | ✅ |
| 440_002 cross_session_discharge | open in run 1, close in run 2 | ✅ |
| 440_003 forged_handle_refused | `close("file_99")` refused BEFORE proc | ✅ |
| 440_004 bridge_session_hangup | close releases what the session holds | ✅ |
| 440_010 guarded_withdrawal | provider outlives dependents at release | ✅ |
| 440_011 lifo_release_order | independent handles release LIFO | ✅ |
| 440_012 redefine_resolves | redefinition truly replaces the body | ✅ |
| 440_013 recovery_exactness | accumulator applies each inverse once | ✅ |
| 440_014 transitive_chain | three-level chain releases leaf-first | ✅ |
| 440_015 dual_provider | both providers outlive the merged handle | ✅ |
| 440_016 false-release gate | unimplemented discharge REFUSED, not silent | ✅ |

440_016 is the strongest possession wall this benchmark measures: a
discharge event declared with the `<!query>` phantom but no implementation
used to get a synthesized no-op handler — the pool printed `Invoked`,
marked the handle released, and close reported success while the resource
was never freed. The register transform now refuses discharge claims
without an implementation; the leak strands and close panics with the
count. The load-bearing walls — forged handle refused, cross-turn
conversation, and now false-release refused — are green and reproducible.

Caveat retired: the `koru_std/rules.kz` uncommitted-modification caveat no
longer applies — the file is clean at `0c2538dd` (the earlier frontend
parse error was resolved upstream).

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