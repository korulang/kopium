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
    |> std/bridge:run(br, source: src)
        | result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
        | partial p |> std/io:print.ln("  {{ p.ran:d }}/{{ p.total:d }} steps ran — bridge holds {{ p.handles:d }}")
        | defined d |> std/io:print.ln("  defined {{ d:s }} — persisted to the world")
        | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
        | unhandled-branch ub |> std/io:print.ln("  UNHANDLED: '{{ ub.branch:s }}' fired, held {{ ub.handles:s }}")
        | event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this session's vocabulary")
        | residue r |> std/io:print.ln("  the model emitted prose — bound as residue: {{ r.report:s }}")
        | parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
        | exhausted _ |> std/io:print.ln("  budget exhausted")
        | validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
        | shape-error s |> std/io:print.ln("  wrong shape: {{ s.message:s }}")
        | scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")
