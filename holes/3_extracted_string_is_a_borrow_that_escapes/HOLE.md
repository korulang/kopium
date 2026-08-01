# Hole 3 — an extracted `string` is a borrow, and returning it hands back freed memory

**Found:** 2026-08-01, driving `d_turns.k` under a pty after the delta ladder
went point-free — the turns worked, the replies came back blank.
**Confidence it's real:** ~95% (headless 20-line repro, no network; the bytes
are NUL and the length survives, which is freed memory and nothing else).

## What it looks like

`koru/yyjson:as.string` returns a `string` that **points into the document's
arena**. Nothing ties that borrow's lifetime to the doc. So the moment the
extracted value leaves the tor that owns the doc, auto-discharge closes the
arena on the way out and the caller reads the corpse:

```koru
tor extract { payload: string }
| ok string
| gone
extract = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "choices")
    |> koru/yyjson:array.get(doc, index: 0)
    |> koru/yyjson:object.get(doc, key: "delta")
    |> koru/yyjson:object.get(doc, key: "content")
    |> koru/yyjson:as.string(doc)
    | not-found |> koru/yyjson:close(doc) => gone
    | out-of-range |> koru/yyjson:close(doc) => gone
    | wrong-type |> koru/yyjson:close(doc) => gone
| err _ => gone

extract(payload: "{\"choices\":[{\"delta\":{\"content\":\"HELLO\"}}]}")
| ok t |> std/io:print.ln("EXTRACTED: [{{ t:s }}]")
| gone |> std/io:print.ln("GONE — extracted nothing")
```

`koruc run input.k` — compiles clean, takes the `| ok` arm (so the ladder
threads correctly), and prints:

    0000000   E X T R A C T E D :   [  \0 \0 \0 \0
    0000020  \0 ]  \n

Five NUL bytes where `HELLO` should be. **The length is right and the content
is gone** — the classic shape of a read through a freed pointer.

## Why it is worth a hole of its own

**It is silent.** No error, no crash, no leak-check failure — exit 0. A test
that asserts "the ok arm fired" passes. Only something that reads the bytes
can see it, and in a TUI those bytes go straight to a pane, so kopium looked
like a working chat client answering every message with silence.

**The refactor that exposed it changed nothing about the ladder's logic.**
Increment A and increment B both work, and they differ from this in exactly
one respect: they *consume* the extracted text inside the arm that owns the
doc (B appends it to the transcript right there, and its comment even says
"append is the last use of the doc's arena, and auto-discharge places the
close"). Going point-free turned that inline consume into a **return**, and
the same six stages started handing back freed memory. So the hazard is not
the chain and not the extraction — it is the **escape**.

## This is 610_007, with a worse witness

`tests/regression/600_STDLIB/610_STRING/610_007_reject_dangling_slice` is
already parked RED on precisely this question for `std/string:read`, and it
says in as many words: *the returned `string` BORROWS s's buffer, and nothing
ties its lifetime to `s`* — with **THE QUESTION FOR LARS (do not answer it by
inventing one)** written above the options. So this hole deliberately proposes
no fix.

What it adds is evidence about severity. 610_007's witness SIGSEGVs at exit
139 — loud, and a harness catches it. This one returns **plausible data of the
correct length** and exits 0. The borrow hole is not only a crash risk; it is a
silent-wrong-answer risk, and it reached a real app through an ordinary
refactor that no reviewer would flag.

The options 610_007 lists are unchanged: a phantom on the returned `string`
tied to the owner's identity, a read-scope construct bounding where the borrow
may travel, or making extraction allocate like `substring` already does
(`koru_std/string.kz:106-113` writes that precedent down — *"cheap views wait
on the borrow-obligation surface"*).

**The want:** returning a borrow past its owner's discharge is a compile error,
whatever the spelling turns out to be. Today it is a blank chat pane.
