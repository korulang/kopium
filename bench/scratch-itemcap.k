// scratch-itemcap.k — differential test: app/tau_wire:item-cap's item count
// vs the count std/bridge:run's own segmenter reports in partial.total.
// Audit scratch — not part of the harness wall.

import std/io
import std/bridge
import std/runtime
import app/tau_wire

tor ping { n: i64 } -> i64
proc ping|zig {
    return n;
}

std/runtime:register(scope: "tcap") {
    ping(1)
}

// A `note: storm` line repeated n times — the 2026-10-11 task-10 wedge shape.
tor storm-src { n: i64 } -> string
proc storm-src|zig {
    const a = @import("std").heap.page_allocator;
    var out = @import("std").ArrayListUnmanaged(u8){};
    var i: i64 = 0;
    while (i < n) : (i += 1) {
        out.appendSlice(a, "note: storm\n") catch @panic("oom");
    }
    return out.items;
}

tor check { label: string, source: string<*> }
check = app/tau_wire:item-cap(source, max: 128)
| ok n |> std/io:print.ln("{{ label:s }} cap-ok {{ n:d }}")
| over n |> std/io:print.ln("{{ label:s }} cap-over {{ n:d }}")

tor real { br: *std/bridge:Bridge<session>, label: string, source: string<*> }
real = std/bridge:run(br, source)
| result r |> std/io:print.ln("{{ label:s }} real=result")
| defined d |> std/io:print.ln("{{ label:s }} real=defined")
| partial p |> std/io:print.ln("{{ label:s }} real=partial total={{ p.total:d }} ran={{ p.ran:d }}")
| unhandled-branch ub |> std/io:print.ln("{{ label:s }} real=unhandled {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("{{ label:s }} real=dispatch {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("{{ label:s }} real=denied {{ ev:s }}")
| residue r |> std/io:print.ln("{{ label:s }} real=residue")
| parse-error p |> std/io:print.ln("{{ label:s }} real=parse {{ p.message:s }}")
| validation-error v |> std/io:print.ln("{{ label:s }} real=invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("{{ label:s }} real=shape {{ sh.message:s }}")
| exhausted e |> std/io:print.ln("{{ label:s }} real=exhausted")
| scope-not-found s |> std/io:print.ln("{{ label:s }} real=noscope")

[with]std/bridge:create(id: "tcap", scope: "tcap", introspection: true): br
|> check(label: "pings3", source: "ping(n: 1)\nping(n: 2)\nping(n: 3)")
|> real(br, label: "pings3", source: "ping(n: 1)\nping(n: 2)\nping(n: 3)")
|> check(label: "colonblock", source: "note: first line\nmore prose here\nping(n: 1)")
|> real(br, label: "colonblock", source: "note: first line\nmore prose here\nping(n: 1)")
|> check(label: "implhead-space", source: "tor foo\nfoo bar\nping(n: 1)")
|> real(br, label: "implhead-space", source: "tor foo\nfoo bar\nping(n: 1)")
|> check(label: "annotated-tor", source: "tor foo[x]\nfoo = ping(n: 1)\nping(n: 2)")
|> real(br, label: "annotated-tor", source: "tor foo[x]\nfoo = ping(n: 1)\nping(n: 2)")
|> check(label: "wellformed-def", source: "tor dbl { x: i64 } -> i64\ndbl = ping(n: x)\nping(n: 2)")
|> real(br, label: "wellformed-def", source: "tor dbl { x: i64 } -> i64\ndbl = ping(n: x)\nping(n: 2)")
|> storm-src(n: 150): s
|> check(label: "storm150", source: s)
|> real(br, label: "storm150", source: s)
