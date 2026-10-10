// corpus-replay.k — deterministic replay of recorded wire programs through
// the real bridge. Same driver shape as verb-check-native.k, but the scope
// and fixture path come from the environment so one binary replays any
// recorded run against either arm:
//   KOPIUM_SCOPE — "airline" (transliterated) or "airline-native" (phantoms);
//   the fixture is corpus-replay.fixture.jsonl, {"source": "<wire>"} per line
//   (the python harness rewrites it before each run's replay).
// The harness (corpus-replay.py) answers the procs' outbound protocol lines
// reactively, so no canned stdin ordering is needed.

import std/io
import std/fmt
import std/bridge
import std/interpreter
import std/string
import app/airline_tools
import app/airline_native
import app/tau_wire
import app/corpus_env
import koru/yyjson

tor run-src { br: *std/bridge:Bridge<session>, src: string }
run-src = std/bridge:run(br, source: src)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/io:print.ln("VALUE {{ v:s }}\n{{ r.trace:s }}")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| partial p |> std/io:print.ln("FAIL-PARTIAL {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL-UNHANDLED {{ ub.branch:s }} {{ ub.payload:s }}")
| dispatch-error e |> std/io:print.ln("{{ e.trace:s }}FAIL-DISPATCH {{ e.event_name:s }} {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("FAIL-DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("FAIL-RESIDUE {{ r.report:s }}")
| parse-error p |> std/io:print.ln("FAIL-PARSE {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL-VALIDATION {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL-SHAPE {{ sh.branch:s }}")
| exhausted _ |> std/io:print.ln("FAIL-EXHAUSTED")
| scope-not-found s2 |> std/io:print.ln("FAIL-SCOPE {{ s2:s }}")

tor one { br: *std/bridge:Bridge<session>, line: string }
one = koru/yyjson:parse(text: line)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "source")
    | found sv |> koru/yyjson:as.string(doc, v: sv)
        | ok src |> run-src(br, src) |> std/io:free(content: src) |> koru/yyjson:close(doc)
        | wrong-type |> std/io:print.ln("FAIL-FIXTURE source not a string") |> koru/yyjson:close(doc)
    | not-found |> std/io:print.ln("FAIL-FIXTURE line has no source") |> koru/yyjson:close(doc)
| err e |> std/io:print.ln("FAIL-FIXTURE not JSON ({{ e.msg:s }})")

app/corpus_env:env-or(key: "KOPIUM_SCOPE", fallback: "airline"): scope
|> app/corpus_env:env-or(key: "KOPIUM_WORLD", fallback: ""): w
|> [with]std/bridge:create(id: "corpus-replay", scope, introspection: true, world: w): br
|> app/tau_wire:saw-eof()
| yes |> std/io:eprint.ln("corpus-replay: stdin already at EOF")
| no |> std/io:read-file(path: "corpus-replay.fixture.jsonl")
    | ok content |> std/string:split(s: content, sep: "\n")
        ! piece line |> one(br, line)
        | done n |> std/io:free(content)
            |> std/io:eprint.ln("corpus-replay: {{ n:d }} fixture lines run on {{ scope:s }}")
    | not-found |> std/io:eprint.ln("corpus-replay: fixture file missing")
    | failed m |> std/io:eprint.ln("corpus-replay: fixture read failed {{ m:s }}")
