# Chain Spelling Reconciliation

## Finding

There are two different questions hiding under "inline continuation":

- **Single flow, same item:** `verb(...) | ok x |> next(x)` is accepted by
  `parse.wire` and by `std/bridge:run`. The bridge pin
  `440_029_bridge_run_typed_args` runs
  `add(a: 5, b: 3) | ok s |> echo-num(n: s)` as one item.
- **Turn segmentation:** `bridge.turnscan` only starts a new item on a
  non-blank line that is not a `|` arm and is not inside open delimiters,
  strings, a `tor` body, or a colon block. A line beginning with `|` is
  always part of the current item, not a fresh item.

So the doc comment in `runtime.parsewire.kz` is not wrong about the parser:
`| ok h |> verb(handle: h)` is a legal inline continuation inside one flow.
The model-facing ambiguity is that a *series* like:

```koru
open()
| ok h |> append(handle: h)
| ok h2 |> close(handle: h2)
```

does not mean "after append, close." The second `| ok` is a sibling arm on
`open`, and the interpreter now refuses the duplicate unguarded same-branch
arm. The intended nested spelling is:

```koru
open()
| ok h |> append(handle: h)
    | ok h2 |> close(handle: h2)
```

That is pinned by `440_027_shadowed_arm_never_fires`: flat repeated branch
arms are siblings; indented arms attach to the step they follow.

## Likely Receipt Mechanism

The brief says receipts show `MalformedNode` for inline continuations while
arm-on-own-line parses. This checkout does not contain `bench/results/runs`,
so I could not inspect those receipts directly. Based on the code and pins,
the likely failure is not "inline arms are absent" but one of these:

- the taught text implied repeated same-branch arms can form a serial chain;
- an inline arm was emitted after a colon `Source` block, where the segmenter
  treats continuation lines as part of captured prose until an invocation-head
  line ends the block;
- the parser accepted the inline flow shape but the interpreted flow validator
  refused its sibling-arm meaning.

## Minimal Fix Proposal

1. Update the model-facing grammar text and `airline_vocab_doc.md` examples to
   teach both laws explicitly:
   - same-line arm after a call is legal for one continuation;
   - a second arm for the next call must be indented under that call, not
     written as another flat `| ok`.

2. Add one bridge pin that exercises the exact airline-shaped serial chain
   in both accepted spellings:

```koru
first()
| ok a |> second(x: a)
    | ok b |> third(x: b)
```

and, if same-line chaining is meant to stay accepted:

```koru
first() | ok a |> second(x: a) | ok b |> third(x: b)
```

3. If the same-line three-link form is *not* intended, change the
   `runtime.parsewire.kz` comment to show only the one-link inline form and
   the multi-line nested form. Do not let prompt prose teach a shape the
   validator later rejects.

