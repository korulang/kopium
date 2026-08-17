// PROBE, not a deliverable. The exact question the wire answers now: does the
// model's prompt derive from the register block instead of a hand-typed
// script? Prints the assembled request body so the derived grammar — the
// wire's shape rules AND the vocabulary — is visible. Both must come from
// std/bridge:grammar, not this file's prose.
import std/io
import std/bridge
import app/wire
import app/notes

std/bridge:create(id: "probe", scope: "notes"): br
|> app/wire:warm-grammar(br)
|> app/wire:agent-body(goal: "open a note called hello.txt", history: ""): body
|> std/io:print.ln("{{ body:s }}")
