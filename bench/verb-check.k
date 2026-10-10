// verb-check.k — deterministic airline verb exerciser. NO model: reads
// bench/verb-check.fixture.jsonl (one JSON object per line, field "source"
// = the wire invocation) and drives each through std/bridge:run on the real
// "airline" scope. The generated procs emit their CALL/SAY lines on stdout
// and block on stdin for the canned reply, exactly as in production —
// bench/verb-check.stdin.jsonl is that reply stream (ids k1..kN are minted
// by app/tau_wire in CALL order; `say` takes a user line, no id).
//
// stdout is the protocol channel: `{"kind":"call"|"say",...}` lines come from
// the procs. Each run's stringified result value is printed as a stdout line
// `VALUE <json>` — the `V` prefix cannot begin a protocol object, so the
// driver (verb-check.sh) splits stdout into outbound.jsonl and values.txt by
// prefix. Any other run outcome prints `FAIL-<arm>` — also non-protocol.
// VALUE lines go through print.ln's 64K scratch, so values above ~64KB
// would truncate loudly (print.ln dies) rather than silently — documented,
// not hit by this fixture (largest result ~12KB).

import std/io
import std/fmt
import std/bridge
import std/interpreter
import std/string
import app/airline_tools
import app/tau_wire
import koru/yyjson

// One run: wire source through the real bridge. Every non-`result` arm of
// std/bridge:run prints a FAIL-<arm> marker so the checker sees it.
tor run-src { br: *std/bridge:Bridge<session>, src: string<*> }
run-src = std/bridge:run(br, source: src)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/io:print.ln("VALUE {{ v:s }}")
| defined d |> std/io:print.ln("FAIL-DEFINED {{ d:s }}")
| partial p |> std/io:print.ln("FAIL-PARTIAL {{ p.report:s }}")
| unhandled-branch ub |> std/io:print.ln("FAIL-UNHANDLED {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("FAIL-DISPATCH {{ e.event_name:s }}")
| event-denied ev |> std/io:print.ln("FAIL-DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("FAIL-RESIDUE {{ r.report:s }}")
| parse-error p |> std/io:print.ln("FAIL-PARSE {{ p.message:s }}")
| validation-error v |> std/io:print.ln("FAIL-VALIDATION {{ v:s }}")
| shape-error sh |> std/io:print.ln("FAIL-SHAPE {{ sh.branch:s }}")
| exhausted _ |> std/io:print.ln("FAIL-EXHAUSTED")
| scope-not-found s2 |> std/io:print.ln("FAIL-SCOPE {{ s2:s }}")

// One fixture line: pull the "source" field, run it, free, close.
tor one { br: *std/bridge:Bridge<session>, line: string }
one = koru/yyjson:parse(text: line)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "source")
    | found sv |> koru/yyjson:as.string(doc, v: sv)
        | ok src |> run-src(br, src) |> std/io:free(content: src) |> koru/yyjson:close(doc)
        | wrong-type |> std/io:print.ln("FAIL-FIXTURE source not a string") |> koru/yyjson:close(doc)
    | not-found |> std/io:print.ln("FAIL-FIXTURE line has no source") |> koru/yyjson:close(doc)
| err e |> std/io:print.ln("FAIL-FIXTURE not JSON ({{ e.msg:s }})")

[with]std/bridge:create(id: "verb-check", scope: "airline", introspection: true): br
// saw-eof is also the Koru-side reference that keeps app/tau_wire in the
// emitted unit — the generated procs reach it proc-side via koru_app, which
// dependency tracking cannot see.
|> app/tau_wire:saw-eof()
| yes |> std/io:eprint.ln("verb-check: stdin already at EOF")
| no |> std/io:read-file(path: "verb-check.fixture.jsonl")
    | ok content |> std/string:split(s: content, sep: "\n")
        ! piece line |> one(br, line)
        | done n |> std/io:free(content)
            |> std/io:eprint.ln("verb-check: {{ n:d }} fixture lines run")
    | not-found |> std/io:eprint.ln("verb-check: fixture file missing")
    | failed m |> std/io:eprint.ln("verb-check: fixture read failed {{ m:s }}")
