// KOPIUM headless — two agents, one resource bridge.
//
// session.k pins that a bridge outlives a turn. This file pins the seam above
// it: a bridge outlives an AGENT. Two scripted agents share one bridge — the
// only thing that makes them distinct is which canned script emitted the
// source; `act` is the same shared verdict dispatch.
//
// The custody story:
//   a1  agent-a opens a note — the bridge mints the handle
//   b1  agent-b appends into a's note — b never opened anything
//   b2  agent-b closes the note — the obligation a created is discharged by b
//   a2  agent-a appends again — the handle is dead for everyone; REFUSED
//
// The bridge is the custody boundary, not the agent. Nobody wrote a handoff;
// the handle pool simply belongs to the resource both agents share.
//
//   koruc handoff.k && ./a.out

import std/bridge
import std/io
import app/notes
import app/relay-model
import app/agent

[with]std/bridge:create(id: "kopium-handoff", scope: "notes"): br
|> std/io:print.ln("--- session open, two agents share one bridge")
|> turn(br, who: "a", n: 1)
|> turn(br, who: "b", n: 1)
|> turn(br, who: "b", n: 2)
|> turn(br, who: "a", n: 2)
|> std/io:print.ln("--- transcript ends")

// One turn: the agent's model emits source, `act` dispatches it against the
// shared bridge. `who` only labels which script produced the text — the
// bridge does not know or care which agent a turn came from.
tor turn { br: *std/bridge:Bridge<session>, who: string, n: u32 }
turn = app/relay-model:intent(who, n): why
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }} [{{ who:s }}]  agent wants to: {{ why:s }}")
    |> app/relay-model:say(who, n): src
    |> std/io:print.ln("  tool> {{ src:s }}")
    |> app/agent:act(br, source: src)
