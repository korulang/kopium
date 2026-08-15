// mock-gate.k — the τ³-bench front door: a line of Koru is the only tool
// surface, vetted by the interpreter.
//
// Protocol (stdin -> stdout):
//   <invocation>  -> OK <event> <value-json>    legal, in-vocabulary; the
//                                                value-json carries the parsed
//                                                args the tor serialized
//                 -> REJECT <detail>            event-denied / not even Koru
//                 -> ERROR <detail>             validation/shape/dispatch
//
// The vocabulary the model is given comes from mock-vocab.k (the interpreter's
// own render of the register block). The args on an OK line are the invocation
// the interpreter PARSED, serialized by the host-side tor stubs — Python
// consumes the gate's JSON and never re-parses Koru itself.
//
//   koruc mock-gate.k && cp a.out mock-gate-binary
//   echo 'create-task(user_id: "user_1", title: "buy milk")' | ./mock-gate-binary

import std/bridge
import std/interpreter
import std/io
import app/mock_tools

pub tor event-name { source: string } -> string

proc event-name|zig {
    var end: usize = 0;
    while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n' and source[end] != '\t') : (end += 1) {}
    return source[0..end];
}

tor vet { br: *std/bridge:Bridge, source: string }
vet = std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): j |> event-name(source): n |> std/io:print.ln("OK {{ n:s }} {{ j:s }}")
| event-denied ev |> std/io:print.ln("REJECT {{ ev:s }}")
| parse-error p |> std/io:print.ln("REJECT {{ p.message:s }}")
| validation-error v |> std/io:print.ln("ERROR {{ v:s }}")
| shape-error s |> std/io:print.ln("ERROR {{ s.message:s }}")
| dispatch-error e |> std/io:print.ln("ERROR {{ e.message:s }}")
| exhausted _ |> std/io:print.ln("ERROR budget exhausted")
| scope-not-found s2 |> std/io:print.ln("ERROR no scope {{ s2:s }}")
| defined _ |> std/io:print.ln("ERROR gate does not define")

std/io:read-stdin()
| ok src |> std/bridge:create(id: "mock-gate", scope: "mock"): br |> vet(br, source: src)
| eof |> std/io:print.ln("ERROR no input")
| failed m |> std/io:print.ln("ERROR {{ m:s }}")