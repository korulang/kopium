// mock-vocab.k — print the mock domain's vocabulary, rendered BY THE
// INTERPRETER from the register block. The model's prompt is built from this
// output; nothing about what the agent may call is typed in Python.
//
//   koruc mock-vocab.k
//   echo x | ./mock-vocab-binary   (stdin is ignored; a read keeps the shape)

import std/io
import std/runtime
import app/mock_tools

std/runtime:scope-vocabulary(name: "mock")
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found |> std/io:print.ln("ERROR scope mock not found")