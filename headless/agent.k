// The agent's act loop — the one piece every canned agent shares.
//
// `act` takes the model's source and runs it against the bridge, then
// reports what the bridge did. All eleven of `std/bridge:run`'s required
// verdicts are named here because each one IS a different agent behaviour —
// a REFUSED means the model guessed a handle, a DENIED means it stepped
// outside the vocabulary, an UNHANDLED means the bridge is holding something
// for next turn. `?partial` is named too, so the step report shows.
//
// An agent file does not re-declare this dispatch. It names a scope, picks
// a model, and lists goals — session.k is the example.

import std/bridge
import std/io

pub tor act { br: *std/bridge:Bridge, source: string }
act = std/bridge:run(br, source)
| result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
| partial p |> std/io:print.ln("  {{ p.ran:d }}/{{ p.total:d }} steps ran — bridge holds {{ p.handles:d }}")
| defined d |> std/io:print.ln("  defined {{ d:s }} — the session's vocabulary now includes it")
| dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED: '{{ ub.branch:s }}' fired, held {{ ub.handles:s }} — carry it to the next turn")
| event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
| residue r |> std/io:print.ln("  the model emitted prose — bound as residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("  budget exhausted")
| validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
| shape-error s |> std/io:print.ln("  wrong shape: {{ s.message:s }}")
| scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")
