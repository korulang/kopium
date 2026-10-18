// Zero-token probe: the exact define shape the grammar line now teaches —
// `tor greet { msg: string }` + `greet = say(text: msg)` — defined through
// bridge:run on the airline scope, then called in the SAME reply.

import std/io
import std/bridge
import std/interpreter
import app/airline_tools
import app/airline_native
import app/corpus_env
import app/tau_wire
import koru/yyjson
import koru/sse
import koru/curl

koru/yyjson:parse(text: "{}")
| ok doc |> koru/yyjson:close(doc)
| err _ |> _

app/tau_wire:scope-name(): sc
|> [with]std/bridge:create(id: "probe-define-say", scope: sc, introspection: true, world: ""): br
|> std/bridge:run(br, source: "tor greet { msg: string }\ngreet = say(text: msg)\ngreet(msg: \"hello from a defined verb\")")
    | defined d |> std/io:print.ln("  defined: {{ d:s }}")
    | result r |> std/interpreter:value.stringify(r.value): j |> std/io:print.ln("  result: {{ j:s }}")
    | partial p |> std/io:print.ln("  partial: {{ p.report:s }}")
    | parse-error p |> std/io:print.ln("  PARSE-ERROR: {{ p.message:s }}")
    | unhandled-branch ub |> std/io:print.ln("  unhandled-branch: {{ ub.branch:s }}")
    | validation-error v |> std/io:print.ln("  validation-error: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  shape-error: {{ sh.message:s }}")
    | event-denied ev |> std/io:print.ln("  event-denied: {{ ev:s }}")
    | dispatch-error e |> std/io:print.ln("  dispatch-error: {{ e.message:s }}")
    | residue rs |> std/io:print.ln("  residue: {{ rs.report:s }}")
    | exhausted _ |> std/io:print.ln("  exhausted")
    | scope-not-found _ |> std/io:print.ln("  scope-not-found")
