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
//   4. Turn 4 defines a verb through `run`, turn 5 calls it — the session's
//      growth mechanism, no register ceremony.
//   5. Turn 6 names a verb nobody declared. It is DENIED at the vocabulary
//      wall: the register block, not a validator. The live wire cannot
//      produce this anymore (its prompt IS the declaration), so the canned
//      turn keeps the wall witnessed.
//   6. Nobody closes anything. The hang-up below is not written in this file —
//      `std/bridge:close` is void, so the compiler appends it, and the note is
//      released on the way out. Compile with `--auto-discharge=disable` and
//      this program is refused by name instead.
//
//   koruc session.k && ./a.out

import std/bridge
import std/io
import app/notes
import app/model
import app/agent

[with]std/bridge:create(id: "kopium-headless", scope: "notes"): br
|> std/io:print.ln("--- session open, the agent's only tool is a Koru interpreter")
|> turn(br, n: 1)
|> turn(br, n: 2)
|> turn(br, n: 3)
|> turn(br, n: 4)
|> turn(br, n: 5)
|> turn(br, n: 6)
|> std/io:print.ln("--- the derived vocabulary now includes the session's inventions")
|> std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("{{ v:s }}")
    |> std/io:print.ln("--- transcript ends; no hang-up is written below this line")
| not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished at hang-up")

// One turn: ask the model, show what it said, act on it. `act` is the shared
// verdict dispatch in app/agent — an agent file names a scope, a model, and
// goals; the twelve-arm report is the harness's, not yours.
// The `br` parameter carries no phantom — a turn USES the session, it does
// not end it. The canned model binds the observed handle itself (handles are
// opaque; nothing is predictable, so a cooperative model never guesses — it
// reads what the observation returned).
tor turn { br: *std/bridge:Bridge, n: u32 }
turn = app/model:intent(turn: n): why
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  model wants to: {{ why:s }}")
    |> app/model:say(turn: n): src
    |> std/io:print.ln("  tool> {{ src:s }}")
    |> app/agent:act(br, source: src)
