// KOPIUM heredity — two sessions, one world.
//
// session.k shows a verb invented and used inside ONE session. This is the
// same moment one rung higher: session A mounts `world/`, does the
// open/append/close dance by hand, names it `log-line`, and closes. Session B
// mounts the same directory on a fresh bridge — `log-line` is already
// vocabulary, and the derived prompt would already contain it.
//
// Possession still dies with the session: the file handle minted under A is
// gone; what survives is the *verb* — durable vocabulary, session-scoped
// handles. Turn b.2 keeps the wall witnessed: a verb nobody defined and
// nobody persisted is still denied.
//
//   rm -rf world && koruc heredity.k && ./a.out && cat world/log-line.k
//
// The world dir lands next to this file; `say` prints each invented line.

import std/bridge
import std/io
import app/notes
import app/hmodel
import app/agent

[with]std/bridge:create(id: "session-a", scope: "notes", world: "world"): a
|> std/io:print.ln("--- session A open — empty world, six registered verbs")
|> aturn(br: a, session: "a", n: 1)
|> aturn(br: a, session: "a", n: 2)
|> aturn(br: a, session: "a", n: 3)
|> aturn(br: a, session: "a", n: 4)
|> aturn(br: a, session: "a", n: 5)
|> std/bridge:close(br: a)
|> std/io:print.ln("--- session A closed; the handle died, the verb did not")
|> std/bridge:create(id: "session-b", scope: "notes", world: "world"): b
|> std/io:print.ln("--- session B open — same world")
|> aturn(br: b, session: "b", n: 1)
|> aturn(br: b, session: "b", n: 2)
|> std/bridge:vocabulary(br: b)
| ok v |> std/io:print.ln("--- session B's derived vocabulary:\n{{ v:s }}")
    |> std/bridge:close(br: b)
    |> std/io:print.ln("--- session B closed")
| not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")

// One turn, same shape as session.k's — ask the model, show the wire, run it,
// show what the bridge did. `session` picks which canned script answers.
tor aturn { br: *std/bridge:Bridge, session: string, n: u32 }
aturn = app/hmodel:intent(session, turn: n): why
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  model wants to: {{ why:s }}")
    |> app/hmodel:say(session, turn: n): src
    |> std/io:print.ln("  tool> {{ src:s }}")
    |> app/agent:act(br, source: src)
