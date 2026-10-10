// Zero-token probe: the possession-shaped callable surface (the HATEOAS
// rooms). `std/bridge:affordances` answers "given what I hold, what can I
// call now?" — the static vocabulary filtered by the live handle pool.
//
// The notes scope declares two possession-gated verbs (`append` and `close`
// consume `<!open>`) and four always-callable ones. The surface must shrink
// and grow with the bridge:
//
//   A  nothing held -> open/read/edit/say only (append/close absent)
//   B  open a note -> append/close appear, note_0 named as held
//   C  close it -> append/close vanish again
//
//   koruc probe_affordances.k && ./a.out

import std/io
import std/bridge
import std/fmt
import app/notes

tor empty { br: *std/bridge:Bridge<session> }
empty = std/io:print.ln("--- A: nothing held, the callable surface ---")
    |> std/bridge:affordances(br)
    | ok v |> std/io:print.ln("{{ v:s }}")
    | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")

tor aff-open { br: *std/bridge:Bridge<session> }
aff-open = std/io:print.ln("--- B: after open, the surface grows ---")
    |> std/bridge:run(br, source: "open(path: \"probe_affordances.txt\")")
    | result r |> std/bridge:affordances(br)
        | ok v |> std/io:print.ln("{{ v:s }}")
        | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("EXHAUSTED")
    | validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")

tor aff-close { br: *std/bridge:Bridge<session> }
aff-close = std/io:print.ln("--- C: after close, the surface shrinks ---")
    |> app/notes:last-minted(): h
    |> std/fmt:ln("close(handle: \"{{ h:s }}\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/bridge:affordances(br)
        | ok v |> std/io:print.ln("{{ v:s }}")
        | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("EXHAUSTED")
    | validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")

[with]std/bridge:create(id: "probe-affordances", scope: "notes"): br
|> empty(br) |> aff-open(br) |> aff-close(br)
