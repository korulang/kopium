// Hole 9 repro: the wire grammar's worked example is notes-shaped.
// On the `calc` scope — which has no `open`, no `append`, no handles —
// the derived prompt still teaches them. Settler extracts the verbs the
// example names and asks whether each is in this scope's vocabulary.
import std/io
import std/bridge
import app/calc

tor show { br: *std/bridge:Bridge }
show = std/bridge:grammar(br)
| ok g |> std/io:print.ln("{{ g:s }}")
| not-found s |> std/io:print.ln("WRONG: no scope {{ s:s }}")

[with]std/bridge:create(id: "repro-9", scope: "calc"): br
|> show(br)
