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

pub tor act { br: *std/bridge:Bridge<session>, source: string }
act = std/bridge:run(br, source)
| result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
| partial p |> std/io:print.ln("  {{ p.ran:d }}/{{ p.total:d }} steps ran — bridge holds {{ p.handles:d }}")
| defined d |> std/io:print.ln("  defined {{ d:s }} — the session's vocabulary now includes it")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED: '{{ ub.branch:s }}' fired, held {{ ub.handles:s }} — carry it to the next turn")
| residue r2 |> std/io:print.ln("  the model emitted prose — bound as residue: {{ r2.report:s }}")
| error e |> std/bridge:error-decode(e)
    | dispatch-error de |> std/io:print.ln("  REFUSED: {{ de.message:s }} — '{{ de.event_name:s }}' never ran")
    | event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
    | parse-error p2 |> std/io:print.ln("  the model did not emit Koru: {{ p2.message:s }}")
    | validation-error v2 |> std/io:print.ln("  invalid: {{ v2:s }}")
    | shape-error s2 |> std/io:print.ln("  wrong shape: {{ s2.message:s }}")
    | exhausted _ |> std/io:print.ln("  budget exhausted")
    | scope-not-found s3 |> std/io:print.ln("  no such scope: {{ s3:s }}")
    | unknown-error u |> std/io:print.ln("  REFUSED({{ u.kind:s }}): {{ u.message:s }}")
