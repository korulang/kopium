// verb-check-native.k — deterministic exerciser for the airline-native
// scope. Same shape as verb-check.k: fixture lines in, outbound protocol
// lines out, one VALUE/FAIL- line per run. The difference is the point:
// this scope's verbs carry possession phantoms, so the fixture also pins
// the REFUSALS — forged literals, wrong tags, and the select/hold/release
// lifecycle that never reaches the wire under the transliterated surface.

import std/io
import std/fmt
import std/bridge
import std/interpreter
import std/string
import app/airline_native
import app/tau_wire
import koru/yyjson

// One run: wire source through the real bridge. dispatch-error prints the
// teaching message too — possession refusals carry it, and the check is
// exactly that the refusal teaches.
tor run-src { br: *std/bridge:Bridge<session>, src: string<*> }
run-src = std/bridge:run(br, source: src)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/io:print.ln("VALUE {{ v:s }}")
| defined d |> std/io:print.ln("FAIL-DEFINED {{ d:s }}")
| partial p |> std/io:print.ln("FAIL-PARTIAL {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL-UNHANDLED {{ ub.branch:s }} {{ ub.payload:s }}")
| dispatch-error e |> std/io:print.ln("FAIL-DISPATCH {{ e.event_name:s }} {{ e.message:s }}")
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

[with]std/bridge:create(id: "verb-check-native", scope: "airline-native", introspection: true): br
|> app/tau_wire:saw-eof()
| yes |> std/io:eprint.ln("verb-check-native: stdin already at EOF")
| no |> std/io:read-file(path: "verb-check-native.fixture.jsonl")
    | ok content |> std/string:split(s: content, sep: "\n")
        ! piece line |> one(br, line)
        | done n |> std/io:free(content)
            |> std/io:eprint.ln("verb-check-native: {{ n:d }} fixture lines run")
    | not-found |> std/io:eprint.ln("verb-check-native: fixture file missing")
    | failed m |> std/io:eprint.ln("verb-check-native: fixture read failed {{ m:s }}")
