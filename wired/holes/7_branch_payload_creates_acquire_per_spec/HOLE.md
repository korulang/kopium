# Hole 7 — a phantom in a branch payload creates an obligation PER SPEC, not per fired branch

**Found:** 2026-09-13, second-vocabulary spike (`headless/ledger.kz`,
`probe_ledger.k` — the first consume+reissue verb whose outcomes are named
branches carrying phantoms).
**Confidence it's real:** ~95% (measured end-to-end; mechanism read off the
emitted manifest and `koru_std/interpreter.run.kz`).

## What it looks like

```kz
~pub tor post { handle: string<!acct>, amount: string }
| ok string<acct!>
| bad-amount string<acct!>
```

compiles fine, and the emitted manifest carries

```
creates_specs = [
  { obligation_name: "acct", field_name: "__type_ref" },   // ok payload
  { obligation_name: "acct", field_name: "__type_ref" }    // bad-amount payload
]
```

— two CreateSpecs with **no branch discriminator**. The acquire loop
(`interpreter.run.kz`, the `creates_spec_fn` block) iterates every spec,
each finds the fired branch's `__type_ref` payload, and the pool acquires
once per spec: **every `post` call creates two undischarged records for the
same handle** while the `<!acct>` consume correctly discharges one.

Measured on `probe_ledger.k` (canned, zero tokens):

| turn | observed |
|---|---|
| `open-acct` | `handles=1` |
| `post` (ok arm handled) | `handles=2` — should be 1 |
| `post` (bad-amount, unhandled) | `held=["h","h","h"]` — should be `["h"]` |
| `close-acct` bound | `handles=2` — discharged one of three records |
| hang-up `dischargeAll` | dispatches `close-acct` per stale record → proc panics on the dead slot, exit 134 |

Control: notes' `append` — same consume+reissue shape but a plain
`-> string<open!>` return, one spec — nets zero (`session.k` holds 1
throughout). The gap only exists because `post` is the first verb to put
the phantom on *branch payloads*. The create-count is a property of the
declaration, not of what ran — phantom obligations are booked for branches
that never fired.

## Why it is worth a hole of its own

Possession is the wall the whole design stands on: `handles=N` is the
resource world a successor session inspects, and `dischargeAll` is the
hang-up that releases it. An inflated pool lies about what is held, and
the hang-up then double-dispatches the discharge verb — a module that
enforces "close what I minted" panics on a handle the pool already let go.
The vocabulary did nothing wrong; the bookkeeping did.

## The want

CreateSpec gains the branch name and the acquire loop fires only the spec
whose branch matched `dispatch_result.branch` — or a ruling that branch
payloads may not carry phantoms (which would be a *larger* hole: a
refusal-armed verb could never preserve possession across the refusal).

## Repro / settler

```bash
sh wired/holes/7_branch_payload_creates_acquire_per_spec/settler.sh
# exit 0 = hole OPEN (post leaves 2 undischarged records, hang-up panics)
# exit 1 = hole CLOSED (post nets zero, probe exits clean)
```

## Verdict — CLOSED 2026-09-14 (was OPEN 2026-09-13)

Settled koru-side in `deb163cd8` ("runtime: a branch-payload create books
the fired branch only"): `CreateSpec` gained `branch` (source spelling;
`null` for a bare return), the registry tags each branch-payload spec with
its branch, and the acquire loop in `interpreter.run.kz` books a spec only
when it names `dispatch_result.branch`. The manifest carries the branch too.
One normalized comparator (`namesEql`, `-`≡`_`, in the new
`interpreter.names` part) serves both the acquire filter and `selectArm` —
the same raw-eql blind spot had also made `| bad-amount b |>` wire arms
unmatchable against the mangled `bad_amount` tag. Pinned by koru regression
`440_022_branch_payload_acquires_once`; settler reports CLOSED and the probe
exits clean (post-ok/post-bad each net zero, hang-up releases once).
