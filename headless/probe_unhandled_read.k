// Zero-token probe: the unhandled-branch hand-back, witnessed on the notes
// bridge.
//
// 430_056 ruling: an interpreted fragment that does not handle an outcome
// hands it back as `unhandled-branch` instead of erroring. The notes scope
// used to have NO named-branch verb — every failure was a printed string, so
// nothing a model could emit produced a hand-back. `read` now returns
// `| ok | missing path`, and this probe drives the four shapes through the
// same `std/bridge:run` (lenient by default) that `live.k`'s `act` calls:
//
//   A  bare read of an absent path — zero-continuation named branch, the
//      exact single-line shape a live model emits. Measured: hands back.
//   B  read with only `| ok` handled, and `missing` fires — the ruling's
//      canonical partial-fragment shape. Measured: hands back.
//   C  bare read of an existing file — zero-continuation `ok` also has no
//      handlers, so it hands back too; the bytes still reach the transcript.
//   D  read with `| ok` handled and `ok` firing — handled branches complete
//      as `result`. Control.
//
//   koruc probe_unhandled_read.k && ./a.out   (needs probe_ub_exists.txt)

import std/io
import std/bridge
import std/interpreter
import app/notes

tor a { br: *std/bridge:Bridge }
a = std/io:print.ln("--- A: bare read of an absent path (zero-continuation) ---")
    |> std/bridge:run(br, source: "read(path: \"no-such-file.txt\")")
    | result r |> std/io:print.ln("  A-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  A-UNHANDLED branch=[{{ ub.branch:s }}] payload={{ ub.payload:s }} held={{ ub.handles:s }}")
    | defined d |> std/io:print.ln("  A-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  A-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  A-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  A-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  A-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  A-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  A-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  A-NO SCOPE: {{ s2:s }}")

tor b { br: *std/bridge:Bridge }
b = std/io:print.ln("--- B: only | ok handled, | missing fires ---")
    |> std/bridge:run(br, source: "read(path: \"no-such-file.txt\")\n| ok |> say(text: \"found\")")
    | result r |> std/io:print.ln("  B-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  B-UNHANDLED branch=[{{ ub.branch:s }}] payload={{ ub.payload:s }} held={{ ub.handles:s }}")
    | defined d |> std/io:print.ln("  B-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  B-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  B-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  B-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  B-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  B-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  B-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  B-NO SCOPE: {{ s2:s }}")

tor c { br: *std/bridge:Bridge }
c = std/io:print.ln("--- C: bare read of an existing file (zero-continuation) ---")
    |> std/bridge:run(br, source: "read(path: \"probe_ub_exists.txt\")")
    | result r |> std/io:print.ln("  C-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  C-UNHANDLED branch=[{{ ub.branch:s }}] payload={{ ub.payload:s }} held={{ ub.handles:s }}")
    | defined d |> std/io:print.ln("  C-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  C-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  C-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  C-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  C-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  C-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  C-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  C-NO SCOPE: {{ s2:s }}")

tor d { br: *std/bridge:Bridge }
d = std/io:print.ln("--- D: | ok handled and | ok fires ---")
    |> std/bridge:run(br, source: "read(path: \"probe_ub_exists.txt\")\n| ok |> say(text: \"found it\")")
    | result r |> std/io:print.ln("  D-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  D-UNHANDLED branch=[{{ ub.branch:s }}] payload={{ ub.payload:s }} held={{ ub.handles:s }}")
    | defined d |> std/io:print.ln("  D-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  D-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  D-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  D-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  D-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  D-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  D-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  D-NO SCOPE: {{ s2:s }}")

[with]std/bridge:create(id: "probe-ub-read", scope: "notes"): br
|> a(br) |> b(br) |> c(br) |> d(br)
