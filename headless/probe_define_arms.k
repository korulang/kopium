// PROBE: does the wire define path accept an ARMED body?
// Body with | ok / | bad arms installed via std/bridge:define, then
// dispatched with values firing each arm. Verbatim output is the verdict.
//
//   koruc probe_define_arms.k && ./a.out
import std/io
import std/bridge
import std/runtime
import std/interpreter

pub tor pick { text: string }
| ok string
| bad string

proc pick|zig {
    const std = @import("std");
    if (std.mem.eql(u8, text, "good")) return .{ .ok = text };
    return .{ .bad = "was not good" };
}

pub tor note { text: string }

proc note|zig {
    const std = @import("std");
    std.debug.print("      note: {s}\n", .{text});
}

std/runtime:register(scope: "armites") {
    pick(1)
    note(1)
}

tor install-and-run { br: *std/bridge:Bridge, src: string, call: string }
install-and-run = std/bridge:define(br, source: src)
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    |> std/bridge:run(br, source: call)
    | result r |> std/interpreter:value.stringify(r.value): v |> std/io:print.ln("  ran ok, returned {{ v:s }}")
    | defined d2 |> std/io:print.ln("  DEFINED {{ d2:s }} — WRONG, should dispatch")
    | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  parse-error: {{ p.message:s }} — ARM REJECTED HERE")
    | exhausted _ |> std/io:print.ln("  exhausted")
    | validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  shape-error: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")
| parse-error e |> std/io:print.ln("DEFINE REFUSED: {{ e.message:s }}")

[with]std/bridge:create(id: "probe-arms", scope: "armites"): br
|> std/io:print.ln("--- armed body: ok arm speaks, bad arm speaks ---")
|> install-and-run(br, src: "tor choose { text: string }\nchoose = pick(text) | ok v |> note(text: \"took ok\") | bad m |> note(text: m)", call: "choose(text: \"good\")")
|> install-and-run(br, src: "tor choose2 { text: string }\nchoose2 = pick(text) | ok v |> note(text: \"took ok\") | bad m |> note(text: m)", call: "choose2(text: \"bad\")")
|> std/io:print.ln("--- done ---")
