// PROBE, not a deliverable. A headed kopium needs the bridge reachable from a
// vaxis arm, and arms cannot see flow bindings — the store is the only channel.
// So: can a store column hold `*std/bridge:Bridge<std/bridge:session!>`?
//
// 690_055's header says owned-resource columns past std/string are "currently
// RED". Its marker and the board both say SUCCESS. This settles which.
import std/io
import std/store
import std/bridge
import app/notes

std/store:new(session, capacity: 2) { *std/bridge:Bridge<std/bridge:session!> }

// A tor with NO parameters reaching the bridge purely through the store — the
// shape a `! tick` or `! key` arm is restricted to.
tor act { src: string }
act = std/store:query(session)
! query br |> std/bridge:run(br, source: src)
    | result r |> std/io:print.ln("  ok — holds {{ r.handles:d }}")
    | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  DENIED {{ ev:s }}")
    | parse-error p |> std/io:print.ln("  not koru: {{ p.message:s }}")
    | exhausted _ |> _
    | validation-error _ |> _
    | shape-error _ |> _
    | scope-not-found _ |> _

std/bridge:create(id: "probe-headed", scope: "notes"): br |> std/store:insert(session) { br }
| row _ |> std/io:print.ln("--- bridge parked in a store")
| full f |> std/bridge:close(br: f)

act(src: "open(path: \"probe-headed.txt\")")
act(src: "append(handle: \"note_0\", text: \"reached through the store\")")
act(src: "close(handle: \"note_9\")")
