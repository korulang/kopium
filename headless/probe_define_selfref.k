// PROBE, not a deliverable. The open edge the double-entry replays named:
// a redefine whose body calls its OWN name. The defined-flows table is a
// live namespace (late binding measured), so the self-call resolves to the
// NEW body — recursion with no declared base case. Before koru 3ec559af1
// nothing stopped it: run carries no budget (metering parked) and no depth
// guard existed — measured: ~294 lines of output then exit 139, a stack
// crash mid-turn. Now a defined dispatch counts defined_depth and refuses
// at 64 by name — the probe verifies the refusal, exit 0, no crash.
//
// Canned, zero-token — two `std/bridge:run` calls over `say` so no handle
// has to cross the wire's quoted-values rule.
//
//   koruc probe_define_selfref.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-define-selfref", scope: "notes"): br
|> std/io:print.ln("--- self-referencing redefine, canned ---")
|> define-run(br)
|> selfref-run(br)
|> positional-run(br)

tor define-run { br: *std/bridge:Bridge<session> }
define-run = std/bridge:run(br, source: "tor echo { m: string }\necho = say(text: m)")
| result r |> std/io:print.ln("result — bridge holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("exhausted")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")

// echo redefined with a body that calls echo — the live namespace resolves
// the self-call to THIS body. If the table snapshotted, the self-call would
// reach the old say-only body and terminate; late binding says it recurses.
// First attempt spelled `echo(m: m)` and the pun rule refused the define at
// install ("redundant explicit label") — a self-call MUST pun (`echo(n)`),
// so the recursive spelling is the only one that installs.
tor selfref-run { br: *std/bridge:Bridge<session> }
selfref-run = std/bridge:run(br, source: "tor echo { n: string }\necho = say(text: \"marker\") | ok q |> echo(n)\necho(n: \"hello\")")
| result r |> std/io:print.ln("result — bridge holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| exhausted e |> std/io:print.ln("exhausted at {{ e.used:d }} on {{ e.last_event:s }}")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")

// The notes-realistic shape: two params passed through positionally —
// `jot(h, m)` is the ONLY self-call spelling, since `h: h` and `m: m` are
// redundant labels the grammar refuses. Measured: installs clean, recurses,
// refused at the cap (64 emit lines = the run's work before the refusal).
tor positional-run { br: *std/bridge:Bridge<session> }
positional-run = std/bridge:run(br, source: "tor jot { h: string, m: string }\njot = say(text: m) | ok q |> jot(h, m)\njot(h: \"x\", m: \"y\")")
| result r |> std/io:print.ln("result — bridge holds {{ r.handles:d }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| exhausted e |> std/io:print.ln("exhausted at {{ e.used:d }} on {{ e.last_event:s }}")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")
