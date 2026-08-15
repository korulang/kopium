// PROBE, not a deliverable. The exact question wire.kz dodged: can a tor whose
// PARAMETER is the bridge read a store-held String inside a sweep arm and hand
// both to std/bridge:run?
import std/io
import std/store
import std/string
import std/bridge
import app/notes

std/store:new(reply, capacity: 2) { *std/string:String<std/string:instance!> }

tor drive { br: *std/bridge:Bridge }
drive = std/store:query(reply)
! query buf |> std/string:read(s: buf): src |> std/bridge:run(br, source: src)
    | result r |> std/io:print.ln("  ok — bridge holds {{ r.handles:d }}")
    | defined d |> std/io:print.ln("  defined {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  DENIED {{ ev:s }}")
    | parse-error p |> std/io:print.ln("  not koru: {{ p.message:s }}")
    | exhausted _ |> _
    | validation-error _ |> _
    | shape-error _ |> _
    | scope-not-found _ |> _

std/string:from-page(text: "open(path: \"probe-note.txt\")")
| ok a |> std/string:take(s: a): t |> std/store:insert(reply) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

std/bridge:create(id: "probe", scope: "notes"): br
|> std/io:print.ln("--- probe: store-held source, bridge as a tor param")
|> drive(br)
