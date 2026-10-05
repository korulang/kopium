// Zero-token probe: the apostrophe in "I'll" opens a string in segmentTurn's
// scanner and swallows every following line — a narration-plus-wire reply
// binds as residue and the wire never becomes an item.
//
//   A  turn-5 reply verbatim — prose with "I'll" + a fully-armed read.
//      Expected: `residue` — the read line never segmented.
//   B  same reply, "I will" — no apostrophe.
//      Expected: `partial` — step 1 residue, step 2 dispatched.
//
//   koruc probe_apostrophe.k && ./a.out

import std/io
import std/bridge
import std/interpreter
import app/notes

tor a { br: *std/bridge:Bridge }
a = std/io:print.ln("--- A: 'I'll' narration above armed read ---")
    |> std/bridge:run(br, source: "I'll read field-journal.txt and report what it contains.\n\nread(path: \"field-journal.txt\") | ok v |> say(text: v) | missing m |> say(text: m) | too-large t |> say(text: t)")
    | result r |> std/io:print.ln("  A-RESULT branch=[{{ r.value.branch:s }}]")
    | partial p |> std/io:print.ln("  A-PARTIAL: {{ p.report:s }}")
    | unhandled-branch ub |> std/io:print.ln("  A-UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("  A-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  A-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  A-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  A-RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  A-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  A-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  A-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  A-SHAPE: {{ sh.message:s }}")
    | scope-not-found s |> std/io:print.ln("  A-NO SCOPE: {{ s:s }}")

tor b { br: *std/bridge:Bridge }
b = std/io:print.ln("--- B: 'I will' — no apostrophe ---")
    |> std/bridge:run(br, source: "I will read field-journal.txt and report what it contains.\n\nread(path: \"field-journal.txt\") | ok v |> say(text: v) | missing m |> say(text: m) | too-large t |> say(text: t)")
    | result r |> std/io:print.ln("  B-RESULT branch=[{{ r.value.branch:s }}]")
    | partial p |> std/io:print.ln("  B-PARTIAL: {{ p.report:s }}")
    | unhandled-branch ub |> std/io:print.ln("  B-UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("  B-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  B-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  B-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  B-RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  B-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  B-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  B-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  B-SHAPE: {{ sh.message:s }}")
    | scope-not-found s |> std/io:print.ln("  B-NO SCOPE: {{ s:s }}")

std/bridge:create(id: "probe-apostrophe", scope: "notes"): br
|> a(br)
|> b(br)
