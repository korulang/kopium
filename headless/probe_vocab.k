// PROBE, not a deliverable. The exact question the old wire.kz asked: does the
// model's prompt derive from the register block instead of a hand-typed script?
// Prints the assembled request body so the derived vocabulary is visible. The
// four event lines must come from scope-vocabulary, not this file's prose.
import std/io
import app/wire
import app/notes

app/wire:warm-vocab()

app/wire:agent-body(goal: "open a note called hello.txt", history: "")
| body s |> std/io:print.ln("{{ s:s }}")