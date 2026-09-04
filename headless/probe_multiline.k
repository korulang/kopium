// PROBE, not a deliverable. The one-invocation law: a two-line reply runs
// its first line, and the drop is feedback rather than silence.
// `extra-lines` discriminates, `clean` keeps the head — both pure text,
// no bridge, no network.
import std/io
import std/string
import app/wire

app/wire:extra-lines(raw: "open(path: a)\nclose(handle: note_0)")
| one |> std/io:print.ln("one — WRONG, expected many(2)")
| many n |> std/io:print.ln("many {{ n:d }} — the dropped line is feedback, not silence")

app/wire:clean(raw: "open(path: a)\nclose(handle: note_0)")
| ok first |> std/string:read(s: first): f |> std/io:print.ln("head runs: [{{ f:s }}]") |> std/string:free(s: first)
| err e |> std/io:print.ln("clean failed: {{ e:s }}")
