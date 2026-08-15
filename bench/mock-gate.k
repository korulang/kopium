// mock-gate.k — the τ³-bench front door: a line of Koru is the only tool
// surface, vetted by the interpreter before Python can execute anything.
//
// Protocol: read one invocation from stdin, dispatch it against the mock scope
// through the bridge, print exactly one machine-readable line, exit.
//
//   OK <event>                                  — legal, in-vocabulary invocation
//   REJECT <name-or-message>                    — event-denied, or not even Koru
//   ERROR <message>                             — validation/shape/dispatch
//
// Python parses the event name from the OK line and builds the τ³ ToolCall
// (Koru spells `create-task`, the harness spells `create_task` — the mapping
// is one mechanical line, the REFUSAL is the register block deciding, never a
// Python if-statement). REJECT/ERROR become the agent's spoken refusal.
//
//   koruc mock-gate.k
//   echo 'create-task(user_id: "user_1", title: "buy milk")' | ./a.out
//   → OK create-task

import std/bridge
import std/io
import app/mock_tools

// The event name is the invocation's first token, up to the '(' — the same
// shape `wire:clean` trusts. Extracted here so the OK line is self-describing
// and Python never re-parses Koru to learn what ran.
pub tor event-name { source: string } -> string

proc event-name|zig {
    var end: usize = 0;
    while (end < source.len and source[end] != '(' and source[end] != ' ' and source[end] != '\n' and source[end] != '\t') : (end += 1) {}
    return source[0..end];
}

tor vet { br: *std/bridge:Bridge, source: string }
vet = std/bridge:run(br, source)
| result _ |> event-name(source): n |> std/io:print.ln("OK {{ n:s }}")
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