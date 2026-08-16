// stress-distinct.k — the HONEST possession claim: held vs forged, at volume.
//
// The claim possession must PROVE is the DISTINCTION, shown in the same
// session at the same time where the pool demonstrably holds its real
// handles:
//   - close(handle: "<actually held>")     -> ACCEPTED, proc runs
//   - close(handle: "<forged>")            -> REFUSED before the proc runs
// "Refuse everything" is not possession (an empty pool refuses by default);
// distinguishing is. This version holds TWO real handles concurrently and
// forges a third, so the concurrency of the claim is under test too:
//
//   0. open(path_a), open(path_b)   -> mint real "note_0" AND "note_1"
//   1. loop N: close(forged)        -> MUST refuse HandleNotHeld (never minted)
//   2. close("note_0"), close("note_1") -> BOTH MUST accept: pool holds them
// If any forged accept, or either real close refuses, possession is broken.
//
// Uses the bridge's OWN pool (br.pool — exactly what std/bridge:run guards
// against). The loop lives in a |zig proc body (the dialect's loop
// construct), mirroring std/runtime:run|zig's exact dispatch fields.
//
//      koruc stress-distinct.k && ./a.out 900

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

    // ---- ARM 0: open TWO real notes into the session -----------------------
    // Real handles minted: note_0 (slot 0), note_1 (slot 1). Both must be
    // held by br.pool afterwards.
    var src0a: [256]u8 = undefined;
    const s0a = std.fmt.bufPrint(&src0a, "open(path: \"/tmp/kopium_2hold_a.txt\")", .{}) catch unreachable;
    _ = interp.run_event.handler(.{
        .source = s0a, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    var src0b: [256]u8 = undefined;
    const s0b = std.fmt.bufPrint(&src0b, "open(path: \"/tmp/kopium_2hold_b.txt\")", .{}) catch unreachable;
    _ = interp.run_event.handler(.{
        .source = s0b, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });

    // ---- ARM 1: N forged closes, while note_0 AND note_1 are held ----------
    var forged_refused: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        // A never-minted but PLAUSIBLE slot (2..6): a model would guess a
        // small slot number, not an impossible one. Must refuse every time.
        var src2: [256]u8 = undefined;
        const s2 = std.fmt.bufPrint(&src2, "close(handle: \"note_{d}\")", .{i % 5 + 2}) catch unreachable;
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

    // ---- ARM 2: BOTH real handles must ACCEPT (pool holds them, procs run).
    const s3a = "close(handle: \"note_0\")";
    const r3a = interp.run_event.handler(.{
        .source = s3a, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    const held_a_accepted = switch (r3a) { .result => true, else => false };

    const s3b = "close(handle: \"note_1\")";
    const r3b = interp.run_event.handler(.{
        .source = s3b, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    const held_b_accepted = switch (r3b) { .result => true, else => false };

    std.debug.print("--- possession DISTINCTION: {d} forged closes while TWO real handles are held\n", .{n});
    std.debug.print("    forged close REFUSED pre-proc   : {d}/{d}\n", .{ forged_refused, n });
    std.debug.print("    held note_0 close ACCEPTED       : {s}\n", .{ if (held_a_accepted) "yes — proc ran" else "NO — BROKEN" });
    std.debug.print("    held note_1 close ACCEPTED       : {s}\n", .{ if (held_b_accepted) "yes — proc ran" else "NO — BROKEN" });
    if (forged_refused == n and held_a_accepted and held_b_accepted) {
        std.debug.print("    RESULT: POSSESSION DISTINGUISHES — {d}/{d} forged refused, both held accepted\n", .{ n, n });
    } else {
        std.debug.print("    RESULT: POSSESSION BROKEN\n", .{});
    }
}

tor drive { br: *std/bridge:Bridge }
drive = hammer(br, n: 900)

[with]std/bridge:create(id: "possession-distinct", scope: "notes"): br
|> drive(br)