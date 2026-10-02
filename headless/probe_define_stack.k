// PROBE, not a deliverable. Can a defined body call an EARLIER defined verb
// (stacking), and does a later redefine rebind the callee (late binding)?
// Canned, zero-token — two `std/bridge:run` calls over `say` so no handle
// has to cross the wire's quoted-values rule. Written after the double-entry
// live run showed a bare `|>` body install clean and refuse at dispatch
// re-parse ("Invalid invocation syntax"); this probe uses the arm shape
// `| ok q |>` and distinct param names (the pun rule forbids `jot(m: m)`).
//
//   koruc probe_define_stack.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-define-stack", scope: "notes"): br
|> std/io:print.ln("--- stacked define + late binding, canned ---")
|> stack-run(br)
|> rebind-run(br)

tor stack-run { br: *std/bridge:Bridge }
stack-run = std/bridge:run(br, source: "tor jot { m: string }\njot = say(text: m)\ntor double { mm: string }\ndouble = jot(m: mm) | ok q |> jot(m: mm)\ndouble(mm: \"first\")")
| result r |> std/io:print.ln("result — bridge holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG tail, the double call should dispatch")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("exhausted")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")

// jot redefined in a SECOND run — the defined table persists across runs —
// then double called unchanged. Late-bound: marker lines show. Snapshot:
// "second" twice, no markers.
tor rebind-run { br: *std/bridge:Bridge }
rebind-run = std/bridge:run(br, source: "tor jot { m: string }\njot = say(text: \"marker\") | ok q |> say(text: m)\ndouble(mm: \"second\")")
| result r |> std/io:print.ln("result — bridge holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG tail")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("exhausted")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")
