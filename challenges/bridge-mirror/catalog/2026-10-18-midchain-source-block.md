# 2026-10-18-midchain-source-block — `|> fmt.blk {…}` parses in arm bodies, PARSE001s in head chains

Construct: **a source block continuing a `|>` chain** — the comptime
transform `std/fmt:fmt.blk { … }: name` used as a mid-chain step instead of
at the flow's root.

Measured this session (kopium `main`, headless/ cwd, three probe programs):

| position | compiled `.k` | bridge `source:` | wire | class |
|---|---|---|---|---|
| flow root — `x = std/fmt:fmt.blk {…}: m -> m` | supported — compiles, `m` produces | n/a — transforms are compile-time; no `fmt` surface reaches the bridge | n/a | supported |
| arm body — `call() \| ok t \|> fmt.blk {…}: m \|> use(m)` | supported — compiles (`/tmp/blk_arm.k`, green this session; same shape as `bench/tau-agent.k` sweeps) | n/a | n/a | supported |
| head chain — `x = call() \|> fmt.blk {…}: m \|> use(m)` | **refused — `PARSE001: Source block missing closing brace`** at the `|> std/fmt:fmt.blk {` line. The closing brace is present — the refusal misnames the construct | n/a | n/a | **gap** |

## Dispositions

- The identical block text parses mid-chain inside an arm body and refuses
  mid-chain in a head chain. Two readings: (a) deliberate grammar narrowing —
  head-chain continuations may simply not open source blocks, in which case
  the diagnostic should say so ("source blocks cannot continue a chain"
  beats "missing closing brace" — the brace is present); (b) parser gap —
  the block scanner runs only in arm-body contexts. Either way the refusal
  lies about the construct today. Float to the compiler session — koru-side
  either way, per the one law. NOTE: compiled while a `--no-cache` board was
  live in the main checkout; the checker was mid-change (KORU030 scoped
  diagnostics landed the same hour). Re-verify against the settled tree
  before pinning.
- Encountered in anger while building `headless/probe_promote.k`: the
  consumer fix is a tor whose root IS the block (`tor f {} -> string` over
  `fmt.blk {…}: m -> m`), which is also the cleaner shape — so this gap has a
  good consumer answer even if the narrowing is intended.

## Repro

`/tmp/blk_test.k` (verbatim below) → `PARSE001` at line 6. Swap the head
chain for an arm body (`/tmp/blk_arm.k` shape above) → compiles.

```koru
import std/io
import std/fmt

tor mk { text: string }
mk = std/io:print.ln("x")
    |> std/fmt:fmt.blk {
        {{ text:s }}
    }: m
    |> std/io:print.ln("{{ m:s }}")
```

Would correct this row: the repro compiles, or the refusal names the real
rule ("source blocks open only at flow root or inside an arm body").
