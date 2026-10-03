// PROBE, not a deliverable. The mem floor measured zero-token: a session
// map over the wire — stash → recall → miss → overwrite → forget →
// keys — plus the composite scope shape (mem verbs alongside a real
// domain's, resolved through one bridge).
//
//   koruc probe_mem.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/mem
import app/wire

// The composite the live agent would hold: one scope, two registers'
// worth of verbs — scope() entries pull whole scopes in by name.
std/runtime:register(scope: "kopium") {
    scope(notes)
    scope(mem)
}

[with]std/bridge:create(id: "probe-mem", scope: "kopium"): br
|> std/io:print.ln("--- session map, canned ---")
|> mem-run(br, label: "stash", source: "stash(key: \"plan\", text: \"two-step\")")
|> mem-run(br, label: "recall-hit", source: "recall(key: \"plan\")")
|> mem-run(br, label: "recall-miss", source: "recall(key: \"nope\")")
|> mem-run(br, label: "stash-overwrite", source: "stash(key: \"plan\", text: \"three-step\")")
|> mem-run(br, label: "recall-after-overwrite", source: "recall(key: \"plan\")")
|> mem-run(br, label: "keys", source: "keys()")
|> mem-run(br, label: "forget", source: "forget(key: \"plan\")")
|> mem-run(br, label: "forget-miss", source: "forget(key: \"plan\")")
|> mem-run(br, label: "keys-after", source: "keys()")
|> mem-run(br, label: "notes-still-denied-free", source: "read(path: \"no-such-file-xyz.txt\")")

tor mem-run { br: *std/bridge:Bridge, label: string, source: string }
mem-run = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ label:s }} -> result")
| unhandled-branch ub |> std/io:print.ln("{{ label:s }} -> unhandled [{{ ub.branch:s }}] {{ ub.payload:s }}")
| defined d |> std/io:print.ln("{{ label:s }} -> defined {{ d:s }}")
| dispatch-error e |> std/io:print.ln("{{ label:s }} -> REFUSED: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("{{ label:s }} -> DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("{{ label:s }} -> residue: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("{{ label:s }} -> parse-error: {{ p.message:s }}")
| exhausted e |> std/io:print.ln("{{ label:s }} -> exhausted at {{ e.used:d }}")
| validation-error v |> std/io:print.ln("{{ label:s }} -> invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("{{ label:s }} -> shape-error: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("{{ label:s }} -> no such scope: {{ s:s }}")
| partial p |> std/io:print.ln("{{ label:s }} -> partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")
