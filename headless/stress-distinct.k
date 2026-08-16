// stress-distinct.k — the HONEST possession claim: held vs forged, at volume.
//
// The earlier stress.k proved the weak half: an empty pool refuses everything.
// That is real enforcement but not the claim. The claim is the DISTINCTION:
//   - close(handle: "<actually held>")     -> ACCEPTED, proc runs
//   - close(handle: "<forged>")            -> REFUSED before the proc runs
// in the SAME session, at the SAME time, where the pool demonstrably holds
// the real handle and not the forged one. That is possession; "refuse all"
// is not.
//
// Structure, all on the real bridge pool (br.pool — the exact pool
// std/bridge:run guards against):
//   0. open(path) once            -> mints the REAL handle "note_0" into the pool
//   1. loop N times: close(forged)-> MUST refuse HandleNotHeld while note_0
//                                     is concurrently held (the distinguishing arm)
//   2. close("note_0")            -> MUST accept: the pool holds it, proc runs
// If any forged accept, or the real close refuses, possession is broken.
//
//      koruc stress-distinct.k && ./a.out 5000

import std/bridge
import std/io
import app/notes

// ============================================================================
// THE BOTH-ARMS HAMMER — over the bridge's real pool
// ============================================================================

tor hammer { br: *std/bridge:Bridge, n: u32 }

proc hammer|zig {
    const rt = @import("root").koru_std.koru_runtime;
    const interp = @import("root").koru_std.koru_interpreter;
    const std = @import("std");
    const scope_name = "notes";

    const scope_result = rt.get_scope_event.handler(.{ .name = scope_name });
    const scope = switch (scope_result) { .scope => |s| s, .not_found => @panic("stress: scope 'notes' not registered") };

    // The bridge's own pool — exactly what std/bridge:run dispatches against.
    const pool: *interp.HandlePool = &br.pool;

    var src_open: [256]u8 = undefined;
    const s_open = std.fmt.bufPrint(&src_open, "open(path: \"/tmp/kopium_distinct_0.txt\")", .{}) catch unreachable;
    _ = interp.run_event.handler(.{
        .source = s_open, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });

    var forged_refused: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        // FORGED handle, never minted: must refuse while note_0 is held.
        var src2: [256]u8 = undefined;
        const s2 = std.fmt.bufPrint(&src2, "close(handle: \"note_{d}\")", .{i % 7 + 1}) catch unreachable;
        const r2 = interp.run_event.handler(.{
            .source = s2, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
            .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
            .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
            .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
            .auto_discharge = false, .defined = null,
        });
        switch (r2) {
            .dispatch_error => |e| {
                if (std.mem.indexOf(u8, e.message, "HandleNotHeld") != null) forged_refused += 1;
            },
            else => {},
        }
    }

    // ARM 2 — the REAL held handle: must ACCEPT (pool holds note_0, proc runs).
    const s3 = "close(handle: \"note_0\")";
    const r3 = interp.run_event.handler(.{
        .source = s3, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    const held_accepted = switch (r3) { .result => true, else => false };

    std.debug.print("--- possession DISTINCTION: {d} forged closes while one real handle is held\n", .{n});
    std.debug.print("    forged close REFUSED pre-proc : {d}/{d}\n", .{ forged_refused, n });
    std.debug.print("    held close (note_0) ACCEPTED   : {s}\n", .{ if (held_accepted) "yes — proc ran" else "NO — BROKEN" });
    if (forged_refused == n and held_accepted) {
        std.debug.print("    RESULT: POSSESSION DISTINGUISHES — {d}/{d} forged refused, held accepted\n", .{ n, n });
    } else {
        std.debug.print("    RESULT: POSSESSION BROKEN\n", .{});
    }
}

tor drive { br: *std/bridge:Bridge }
drive = hammer(br, n: 900)

[with]std/bridge:create(id: "possession-distinct", scope: "notes"): br
|> drive(br)