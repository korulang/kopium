// The mock register on the live-session shape.
//
// `session.k` is this program against `notes`. `mock-vocab.k` is this
// register against `scope-vocabulary` with no Bridge. The fork: mock
// never sat on `[with] create` + canned `run` + `std/bridge:vocabulary`,
// so inventions never joined the derived prompt the way notes does.
//
//   koruc session-mock.k && cp a.out session-mock-binary

import std/bridge
import std/io
import app/mock_tools
import app/mock_session_model

[with]std/bridge:create(id: "session-mock", scope: "mock"): br
|> std/io:print.ln("--- session open, mock vocabulary, live-session shape")
|> turn(br, n: 1)
|> turn(br, n: 2)
|> turn(br, n: 3)
|> turn(br, n: 4)
|> turn(br, n: 5)
|> std/io:print.ln("--- vocabulary (register + inventions)")
|> std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("{{ v:s }}")
    |> std/io:print.ln("--- transcript ends")
| not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished at hang-up")

tor turn { br: *std/bridge:Bridge, n: u32 }
turn = app/mock_session_model:intent(turn: n): why
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  model wants to: {{ why:s }}")
    |> app/mock_session_model:say(turn: n): src
    |> std/io:print.ln("  tool> {{ src:s }}")
    |> std/bridge:run(br, source: src)
        | result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
        | unhandled-branch _ |> std/io:print.ln("  UNHANDLED (discard)")
        | defined d |> std/io:print.ln("  defined {{ d:s }} — the session's vocabulary now includes it")
        | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
        | event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
        | residue r |> std/io:print.ln("  the model emitted prose — bound as residue: {{ r.report:s }}")
        | parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
        | exhausted _ |> std/io:print.ln("  budget exhausted")
        | validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
        | shape-error s |> std/io:print.ln("  wrong shape: {{ s.message:s }}")
        | scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")

