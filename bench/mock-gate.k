// mock-gate.k — the τ³-bench front door: a line of Koru is the only tool
// surface, vetted by the interpreter.
//
// Protocol (one source in, one status out, same Bridge until stdin EOF):
//   <invocation>\n                    -> OK <event> <value-json>
//   tor <name> { <args> }\n<body>\n   -> DEFINED <name>
//   vocabulary() / grammar()\n        -> OK <verb> {..<render>..}
//                                     -> REJECT <detail>
//                                     -> HALT <event> <branch> <payload> held: <handles>
//                                     -> ERROR <detail>
// Introspection is a wire verb granted at create(introspection: true) —
// there is no out-of-band command channel. A definition is two statements
// in one run() source (session.k). The second readln is that body; readln's
// buffer dies on the next read, so intake copies before it.
//
//   koruc mock-gate.k && cp a.out mock-gate-binary

import std/bridge
import std/interpreter
import std/io
import app/mock_tools
import app/gate_intake

pub tor event-name { source: string } -> string

proc event-name|zig {
    var end: usize = 0;
    while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n' and source[end] != '\t') : (end += 1) {}
    return source[0..end];
}

// Same split as airline-gate: report the verdict, then settle drains the
// turn's call_step records as a framed CALLSTEPS block.
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

[with]std/bridge:create(id: "mock-gate", scope: "mock", introspection: true): br
|> serve(br)
