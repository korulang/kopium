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

tor handle { br: *std/bridge:Bridge, source: string }
handle = std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): j |> event-name(source): n |> std/io:print.ln("OK {{ n:s }} bound={{ r.bound:s }} {{ j:s }}")
| unhandled-branch ub |> event-name(source): n |> std/io:print.ln("HALT {{ n:s }} {{ ub.branch:s }} {{ ub.payload:s }} held: {{ ub.handles:s }}")
| partial p |> app/gate_intake:emit-framed(tag: "STEPS", text: p.report)
| event-denied ev |> std/io:print.ln("REJECT {{ ev:s }}")
| parse-error p |> std/io:print.ln("REJECT {{ p.message:s }}")
| validation-error v |> std/io:print.ln("ERROR {{ v:s }}")
| shape-error s |> std/io:print.ln("ERROR {{ s.message:s }}")
| dispatch-error e |> std/io:print.ln("ERROR {{ e.message:s }}")
| exhausted _ |> std/io:print.ln("ERROR budget exhausted")
| scope-not-found s2 |> std/io:print.ln("ERROR no scope {{ s2:s }}")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")

tor serve { br: *std/bridge:Bridge }
serve = std/io:readln()
| line src |> app/gate_intake:intake(first: src)
    | ready full |> handle(br, source: full) |> serve(br)
    | incomplete |> std/io:print.ln("ERROR incomplete definition")
    | failed m |> std/io:print.ln("ERROR {{ m:s }}")
| eof |> _
| failed m |> std/io:print.ln("ERROR {{ m:s }}")

[with]std/bridge:create(id: "mock-gate", scope: "mock", introspection: true): br
|> serve(br)
