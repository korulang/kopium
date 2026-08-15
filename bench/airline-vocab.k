// airline-vocab.k — the airline domain's vocabulary, rendered by the
// interpreter from its register block. See mock-vocab.k.

import std/io
import std/runtime
import app/airline_tools

std/runtime:scope-vocabulary(name: "airline")
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found |> std/io:print.ln("ERROR scope airline not found")