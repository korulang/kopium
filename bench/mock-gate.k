// mock-gate.k — the τ³-bench front door: a line of Koru is the only tool
// surface, vetted by the interpreter.
//
// Protocol (one source in, one status out, same Bridge until stdin EOF):
//   <invocation>\n                    -> OK <event> <value-json>
//   tor <name> { <args> }\n<body>\n   -> DEFINED <name>
//   .vocabulary\n                     -> VOCAB-BEGIN … VOCAB-END
//   .grammar\n                        -> GRAMMAR-BEGIN … GRAMMAR-END
//                                     -> REJECT <detail>
//                                     -> ERROR <detail>
// A definition is two statements in one run() source (session.k). The
// second readln is that body; readln's buffer dies on the next read, so
// intake copies before it.
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
| result r |> std/interpreter:value.stringify(r.value): j |> event-name(source): n |> std/io:print.ln("OK {{ n:s }} {{ j:s }}")
| event-denied ev |> std/io:print.ln("REJECT {{ ev:s }}")
| parse-error p |> std/io:print.ln("REJECT {{ p.message:s }}")
| validation-error v |> std/io:print.ln("ERROR {{ v:s }}")
| shape-error s |> std/io:print.ln("ERROR {{ s.message:s }}")
| dispatch-error e |> std/io:print.ln("ERROR {{ e.message:s }}")
| exhausted _ |> std/io:print.ln("ERROR budget exhausted")
| scope-not-found s2 |> std/io:print.ln("ERROR no scope {{ s2:s }}")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")

tor show-vocab { br: *std/bridge:Bridge }
show-vocab = std/bridge:vocabulary(br)
| ok v |> app/gate_intake:emit-framed(tag: "VOCAB", text: v)
| not-found s |> std/io:print.ln("ERROR no scope {{ s:s }}")

tor show-grammar { br: *std/bridge:Bridge }
show-grammar = std/bridge:grammar(br)
| ok g |> app/gate_intake:emit-framed(tag: "GRAMMAR", text: g)
| not-found s |> std/io:print.ln("ERROR no scope {{ s:s }}")

tor serve { br: *std/bridge:Bridge }
serve = std/io:readln()
| line src |> app/gate_intake:intake(first: src)
    | ready full |> app/gate_intake:kind(source: full)
        | vocabulary |> show-vocab(br) |> serve(br)
        | grammar |> show-grammar(br) |> serve(br)
        | run src2 |> handle(br, source: src2) |> serve(br)
    | incomplete |> std/io:print.ln("ERROR incomplete definition")
    | failed m |> std/io:print.ln("ERROR {{ m:s }}")
| eof |> _
| failed m |> std/io:print.ln("ERROR {{ m:s }}")

[with]std/bridge:create(id: "mock-gate", scope: "mock"): br
|> serve(br)
