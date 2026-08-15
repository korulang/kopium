// KOPIUM headless — an agent whose ONLY tool is a Koru interpreter, running
// against a resource bridge that outlives every turn.
//
// There is no tool schema, no argument validator and no cleanup pass. The
// model emits one invocation per turn; `std/bridge:run` dispatches it against
// the `notes` scope; the resources it opens sit on the bridge until someone
// lets go of them.
//
// Four things this is here to show, in the order they happen:
//
//   1. Turn 1 opens a note. The turn ENDS and the note is still held.
//   2. Turn 2 writes into the note turn 1 opened — a different program,
//      reaching a resource it did not create.
//   3. Turn 3 names a handle that was never issued. It is REFUSED before the
//      proc runs, so a wrong answer costs a diagnostic instead of somebody
//      else's file descriptor.
//   4. Nobody closes anything. The hang-up below is not written in this file —
//      `std/bridge:close` is void, so the compiler appends it, and the note is
//      released on the way out. Compile with `--auto-discharge=disable` and
//      this program is refused by name instead.
//
//   koruc session.k && ./a.out

import std/bridge
import std/io
import app/notes
import app/model

[with]std/bridge:create(id: "kopium-headless", scope: "notes"): br
|> std/io:print.ln("--- session open, the agent's only tool is a Koru interpreter")
|> turn(br, n: 1)
|> turn(br, n: 2)
|> turn(br, n: 3)
|> std/io:print.ln("--- transcript ends; no hang-up is written below this line")

// One turn: ask the model, show what it said, run it against the bridge, show
// what the bridge did. The `br` parameter carries no phantom — a turn USES the
// session, it does not end it.
tor turn { br: *std/bridge:Bridge, n: u32 }
turn = app/model:intent(turn: n): why
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  model wants to: {{ why:s }}")
    |> app/model:say(turn: n): src
    |> std/io:print.ln("  tool> {{ src:s }}")
    |> std/bridge:run(br, source: src)
        | result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
        | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
        | event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
        | parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
        | exhausted _ |> std/io:print.ln("  budget exhausted")
        | validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
        | shape-error s |> std/io:print.ln("  wrong shape: {{ s.message:s }}")
        | scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")
