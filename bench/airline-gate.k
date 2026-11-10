// airline-gate.k — same persistent protocol as mock-gate.k.
// One Bridge for the process; one run() source in, one status line out.

import std/bridge
import std/interpreter
import std/io
import app/airline_tools
import app/gate_intake
import app/tau_wire
import koru/yyjson

pub tor event-name { source: string } -> string

proc event-name|zig {
    var end: usize = 0;
    while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n' and source[end] != '\t') : (end += 1) {}
    return source[0..end];
}

// `handle` reports the verdict, then `settle` drains the bridge's
// call_step stream — one framed CALLSTEPS block per turn that dispatched,
// emitted AFTER the verdict line so the session parser reads status first.
tor handle { br: *std/bridge:Bridge<session>, source: string }
handle = report-turn(br, source) |> settle(br)

tor report-turn { br: *std/bridge:Bridge<session>, source: string }
report-turn = std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): j |> event-name(source): n |> std/io:print.ln("OK {{ n:s }} bound={{ r.bound:s }} {{ j:s }}\n{{ r.trace:s }}")
| error e |> std/bridge:error-decode(e)
    | event-denied ev |> std/io:print.ln("REJECT {{ ev:s }}")
    | parse-error p |> std/io:print.ln("REJECT {{ p.message:s }}")
    | validation-error v |> std/io:print.ln("ERROR {{ v:s }}")
    | shape-error s |> std/io:print.ln("ERROR {{ s.message:s }}")
    | dispatch-error de |> std/io:print.ln("{{ de.trace:s }}ERROR {{ de.event_name:s }} {{ de.message:s }}")
    | exhausted _ |> std/io:print.ln("ERROR budget exhausted")
    | scope-not-found s2 |> std/io:print.ln("ERROR no scope {{ s2:s }}")
    | unknown-error u |> std/io:print.ln("ERROR {{ u.kind:s }} {{ u.message:s }}")
| unhandled-branch ub |> event-name(source): n |> std/io:print.ln("HALT {{ n:s }} {{ ub.branch:s }} {{ ub.payload:s }} held: {{ ub.handles:s }}")
| partial p |> app/gate_intake:emit-framed(tag: "STEPS", text: p.report)
| residue r |> std/io:print.ln("REJECT {{ r.report:s }}")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")

// Drain the turn's call_step records — the structured per-dispatch log
// the runlog joins against. Emitted after the verdict, framed like STEPS.
tor settle { br: *std/bridge:Bridge<session> }
settle = std/bridge:take-calls(br): j |> app/gate_intake:emit-framed-nonempty(tag: "CALLSTEPS", text: j)

tor serve { br: *std/bridge:Bridge<session> }
serve = std/io:readln()
| line src |> app/gate_intake:intake(first: src)
    | ready full |> handle(br, source: full) |> serve(br)
    | incomplete |> std/io:print.ln("ERROR incomplete definition")
    | failed m |> std/io:print.ln("ERROR {{ m:s }}")
| eof |> _
| failed m |> std/io:print.ln("ERROR {{ m:s }}")

[with]std/bridge:create(id: "airline-gate", scope: "airline", introspection: true): br
// Two module touches keep the emitted unit whole: saw-eof keeps app/tau_wire
// (airline_tools procs reach it via koru_app), and the trivial yyjson open/close
// keeps koru/yyjson (tau_wire procs reach it via koru_koru) — dependency
// tracking cannot see proc-side references in either case.
|> app/tau_wire:saw-eof()
| yes |> _
| no |> koru/yyjson:parse(text: "{}")
    | ok doc |> koru/yyjson:close(doc) |> serve(br)
    | err _ |> serve(br)

