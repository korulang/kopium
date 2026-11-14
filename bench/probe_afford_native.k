// Zero-token probe: the possession-shaped callable surface on the
// airline-native scope. Empty pool first, then the runtime projection
// for the handle types a mutation workflow mints — the answer to
// "does cancel-reservation become callable once a reservation-known
// handle exists?"
//
//   koruc probe_afford_native.k && ./a.out

import std/io
import std/bridge
import std/runtime
import app/native_protocol
import app/tau_wire
import koru/yyjson

tor show-runtime { held: string }
show-runtime = std/runtime:scope-affordances(name: "airline-native", held)
| ok v |> std/io:print.ln("=== held: {{ held:s }} ===\n{{ v:s }}")
| not-found |> std/io:print.ln("!! scope not found")

tor afford-run { br: *std/bridge:Bridge<session> }
afford-run = std/bridge:affordances(br)
| ok v |> std/io:print.ln("=== bridge affordances (no handles) ===\n{{ v:s }}")
    |> show-runtime(held: "")
    |> show-runtime(held: "user-known")
    |> show-runtime(held: "reservation-known")
    |> show-runtime(held: "found")
    |> show-runtime(held: "chosen")
    |> show-runtime(held: "held")
| not-found s |> std/io:print.ln("!! bridge scope {{ s:s }} vanished")

[with]std/bridge:create(id: "probe-afford-native", scope: "airline-native", introspection: true): br
|> app/tau_wire:saw-eof()
| yes |> afford-run(br)
| no |> koru/yyjson:parse(text: "{}")
    | ok doc |> koru/yyjson:close(doc) |> afford-run(br)
    | err _ |> afford-run(br)
