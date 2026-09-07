// THROWAWAY (delete after run): slot recycle — close then reopen reuses the name,
// and nine opens with closes never panic.
import std/io
import std/bridge
import app/notes

tor cycle { br: *std/bridge:Bridge, path: string, label: string }
cycle = std/bridge:run(br, source: "open(path: \"{{ path:s }}\")")
| result r |> std/io:print.ln("{{ label:s }} opened, pool holds {{ r.handles:d }}")
| defined d |> std/io:print.ln("{{ label:s }} DEFINED {{ d:s }} — WRONG")
| exhausted _ |> std/io:print.ln("{{ label:s }} exhausted — WRONG")
| parse-error p |> std/io:print.ln("{{ label:s }} parse-error: {{ p.message:s }} — WRONG")
| validation-error v |> std/io:print.ln("{{ label:s }} invalid: {{ v:s }} — WRONG")
| shape-error sh |> std/io:print.ln("{{ label:s }} shape-error: {{ sh.message:s }} — WRONG")
| event-denied ev |> std/io:print.ln("{{ label:s }} DENIED {{ ev:s }} — WRONG")
| dispatch-error e |> std/io:print.ln("{{ label:s }} REFUSED: {{ e.message:s }} — WRONG")
| scope-not-found s2 |> std/io:print.ln("{{ label:s }} no such scope: {{ s2:s }} — WRONG")

tor shut { br: *std/bridge:Bridge, handle: string, label: string }
shut = std/bridge:run(br, source: "close(handle: \"{{ handle:s }}\")")
| result r |> std/io:print.ln("{{ label:s }} closed")
| defined d |> std/io:print.ln("{{ label:s }} DEFINED {{ d:s }} — WRONG")
| exhausted _ |> std/io:print.ln("{{ label:s }} exhausted — WRONG")
| parse-error p |> std/io:print.ln("{{ label:s }} parse-error: {{ p.message:s }} — WRONG")
| validation-error v |> std/io:print.ln("{{ label:s }} invalid: {{ v:s }} — WRONG")
| shape-error sh |> std/io:print.ln("{{ label:s }} shape-error: {{ sh.message:s }} — WRONG")
| event-denied ev |> std/io:print.ln("{{ label:s }} DENIED {{ ev:s }} — WRONG")
| dispatch-error e |> std/io:print.ln("{{ label:s }} REFUSED: {{ e.message:s }} — WRONG")
| scope-not-found s2 |> std/io:print.ln("{{ label:s }} no such scope: {{ s2:s }} — WRONG")

[with]std/bridge:create(id: "probe-slots", scope: "notes"): br
|> cycle(br, path: "/tmp/slot-a.txt", label: "open1")
|> shut(br, handle: "note_0", label: "close1")
|> cycle(br, path: "/tmp/slot-b.txt", label: "open2-reuses?")
|> shut(br, handle: "note_0", label: "close2")
|> cycle(br, path: "/tmp/slot-c.txt", label: "open3")
|> shut(br, handle: "note_0", label: "close3")
|> cycle(br, path: "/tmp/slot-d.txt", label: "open4")
|> shut(br, handle: "note_0", label: "close4")
|> cycle(br, path: "/tmp/slot-e.txt", label: "open5")
|> shut(br, handle: "note_0", label: "close5")
|> cycle(br, path: "/tmp/slot-f.txt", label: "open6")
|> shut(br, handle: "note_0", label: "close6")
|> cycle(br, path: "/tmp/slot-g.txt", label: "open7")
|> shut(br, handle: "note_0", label: "close7")
|> cycle(br, path: "/tmp/slot-h.txt", label: "open8")
|> shut(br, handle: "note_0", label: "close8")
|> cycle(br, path: "/tmp/slot-i.txt", label: "open9")
|> shut(br, handle: "note_0", label: "close9")
|> cycle(br, path: "/tmp/slot-j.txt", label: "open10")
|> shut(br, handle: "note_0", label: "close10")
|> std/io:print.ln("--- done, no panic on 9 opens ---")
