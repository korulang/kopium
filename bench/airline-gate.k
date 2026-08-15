// airline-gate.k — the airline-domain front door, same shape as mock-gate.k.
//
// Reads one invocation from stdin, dispatches it against the airline scope
// through the bridge, prints one machine-readable line:
//
//   OK <event>       | the verb is in the register block
//   REJECT <detail>  | event-denied or not even Koru
//   ERROR <detail>   | validation/shape/dispatch
//
// Python maps OK <event> to a τ³ ToolCall. REJECT/ERROR become spoken
// refusals — which for the showcase task (late cancellation) is the CORRECT
// outcome: `say(...)` and no tool call, DB byte-identical to gold.

import std/bridge
import std/interpreter
import std/io
import app/airline_tools

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
| ok src |> std/bridge:create(id: "airline-gate", scope: "airline"): br |> vet(br, source: src)
| eof |> std/io:print.ln("ERROR no input")
| failed m |> std/io:print.ln("ERROR {{ m:s }}")