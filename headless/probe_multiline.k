// PROBE, not a deliverable. The wire now carries partial programs: a turn may
// hold several invocations, and `std/bridge:run` sequences them, reporting one
// step at a time. `clean` keeps the WHOLE turn — it used to truncate to the
// head and `extra-lines` reported the drop. This probe runs a two-invocation
// reply through the real intake and the real bridge, canned: no network, no
// model, no spend.
//
//   koruc probe_multiline.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-multiline", scope: "notes"): br
|> std/io:print.ln("--- wire law: a multi-item turn sequences through clean + bridge ---")
|> two-invocations(br)
|> std/io:print.ln("--- done ---")

tor two-invocations { br: *std/bridge:Bridge }
two-invocations = app/wire:clean(raw: "say(text: \"one\")\nsay(text: \"two\")")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> std/io:print.ln("clean kept: [{{ src.text:s }}]")
    |> report(br, source: src.text)
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean failed: {{ e:s }}")

tor report { br: *std/bridge:Bridge, source: string }
report = std/bridge:run(br, source)
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }} — both lines ran, one report per step")
| result r |> std/io:print.ln("WRONG: result handles={{ r.handles:d }} — a two-item turn is not a single result")
| defined d |> std/io:print.ln("WRONG: defined {{ d:s }} — two invocations are not a declaration")
| unhandled-branch ub |> std/io:print.ln("WRONG: unhandled {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("WRONG: refused {{ e.event_name:s }}: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("WRONG: denied {{ ev:s }}")
| residue r |> std/io:print.ln("RESIDUE {{ r.report:s }}")
| parse-error p |> std/io:print.ln("WRONG: parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("WRONG: exhausted")
| validation-error v |> std/io:print.ln("WRONG: invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("WRONG: shape {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("WRONG: no scope {{ s2:s }}")
