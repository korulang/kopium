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

**Status: partial — measured on a tree where a concurrent full suite ran.
Re-verify from `test-results/latest.json` after a clean suite; see the
lock note below.**

Isolated single-test runs on a lock-free tree (green, all verified by
`run_single_test.sh` directly):

| test | property | isolated |
|---|---|---|
| 440_001 bridge_basic | session create + hold | ✅ |
| 440_002 cross_session_discharge | open in run 1, close in run 2 | ✅ |
| 440_003 forged_handle_refused | `close("file_99")` refused BEFORE proc | ✅ |
| 440_004 bridge_session_hangup | close releases what the session holds | ✅ |
| 440_006 bridge_run_turns_in_koru | whole conversation as pure .k | ✅ |
| 440_010 guarded_withdrawal | withdrawal refuses one held not many | ✅ |

**Not-yet-verified without lock contention:** 440_005, 440_007, 440_008,
440_009, 440_011, 440_012, 440_013. Batch results for these flipped
between runs — the flapping traced to a concurrent suite holding the
`.koru-suite` lock (single-test runs then fail-fast with a lock message,
not a real test result), plus a stale-`FAILURE`-marker artifact in three
test dirs (001/002/004) that only a `rm` cleared. Both are harness
mechanics, not test semantics — re-verify these against a clean suite
snapshot before quoting any of them.

**Root caveat, from the branch's own wall:**
`frag-a-board-measured-on-a-dirty-tree-is-not-reproducible` — this
scorecard was measured mid-flight and is therefore not final. The
load-bearing walls (forged handle refused, cross-turn run) are green;
the full family needs one uncontended suite to call it.

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