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
//   0. open(path_a), open(path_b)   -> mint TWO real opaque handles
//   1. loop N: close(forged)        -> MUST refuse HandleNotHeld (never minted;
//      the forged names are 6-hex, guaranteed distinct from the live ids)
//   2. close(<real a>), close(<real b>) -> BOTH MUST accept: pool holds them
// If any forged accept, or either real close refuses, possession is broken.
// The real handles are READ from the pool — the only legal way to know an
// opaque handle (Lars ruling 2026-09-07/08).
//
// Uses the bridge's OWN pool (br.pool — exactly what std/bridge:run guards
// against). The loop lives in a |zig proc body (the dialect's loop
// construct), mirroring std/runtime:run|zig's exact dispatch fields.
//
//      koruc stress-distinct.k && ./a.out 900
//
// Exit contract: exit 0 = possession held (all forged refused, reals
// accepted); exit 1 = possession broken. Nothing parses stdout; the
// process itself is the verdict.

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

    // N from argv[1], default is the passed n (900 in the driver).
    var count: u32 = n;
    const alloc = std.heap.page_allocator;
    if (std.process.argsAlloc(alloc)) |args| {
        defer std.process.argsFree(alloc, args);
        if (args.len > 1) {
            count = std.fmt.parseInt(u32, args[1], 10) catch count;
        }
    } else |_| {}

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

    // The two real handles, READ from the pool — the only legal way to know
    // an opaque handle. Nothing is predictable; possession is observation.
    var held_ids: [2][]const u8 = undefined;
    var held_count: usize = 0;
    for (pool.handles.items) |hh| {
        if (!hh.discharged and held_count < 2) {
            held_ids[held_count] = hh.handle_id;
            held_count += 1;
        }
    }
    if (held_count != 2) @panic("stress: expected 2 live handles after ARM 0");

    // ---- ARM 1: N forged closes, while both real handles are held ----------
    var forged_refused: u32 = 0;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        // A fabricated opaque name, guaranteed to differ from BOTH live ids
        // by construction — a model that cannot predict must still be refused.
        var forged_hex: [7]u8 = undefined;
        var fv: u32 = i *% 2654435761;
        var collides = true;
        while (collides) : (fv +%= 1) {
            _ = std.fmt.bufPrint(&forged_hex, "{x:0>6}", .{fv % 0x1000000}) catch unreachable;
            collides = false;
            for (held_ids[0..held_count]) |hid| {
                if (std.mem.eql(u8, hid, &forged_hex)) {
                    collides = true;
                    break;
                }
            }
        }
        var src2: [256]u8 = undefined;
        const s2 = std.fmt.bufPrint(&src2, "close(handle: \"{s}\")", .{&forged_hex}) catch unreachable;
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
    var src3a: [256]u8 = undefined;
    const s3a = std.fmt.bufPrint(&src3a, "close(handle: \"{s}\")", .{held_ids[0]}) catch unreachable;
    const r3a = interp.run_event.handler(.{
        .source = s3a, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    const held_a_accepted = switch (r3a) { .result => true, else => false };

    var src3b: [256]u8 = undefined;
    const s3b = std.fmt.bufPrint(&src3b, "close(handle: \"{s}\")", .{held_ids[1]}) catch unreachable;
    const r3b = interp.run_event.handler(.{
        .source = s3b, .dispatcher = scope.dispatcher, .cost_fn = scope.cost_fn,
        .creates_obligations_fn = scope.creates_obligations_fn, .discharges_obligations_fn = scope.discharges_obligations_fn,
        .discharge_event_fn = scope.discharge_event_fn, .creates_spec_fn = scope.creates_spec_fn, .discharges_spec_fn = scope.discharges_spec_fn,
        .budget = null, .handle_pool = pool, .fail_fast = true, .scope_name = scope_name,
        .auto_discharge = false, .defined = null,
    });
    const held_b_accepted = switch (r3b) { .result => true, else => false };

    std.debug.print("--- possession DISTINCTION: {d} forged closes while TWO real handles are held\n", .{count});
    std.debug.print("    forged close REFUSED pre-proc   : {d}/{d}\n", .{ forged_refused, count });
    std.debug.print("    held {s} close ACCEPTED       : {s}\n", .{ held_ids[0], if (held_a_accepted) "yes — proc ran" else "NO — BROKEN" });
    std.debug.print("    held {s} close ACCEPTED       : {s}\n", .{ held_ids[1], if (held_b_accepted) "yes — proc ran" else "NO — BROKEN" });
    if (forged_refused == count and held_a_accepted and held_b_accepted) {
        std.debug.print("    RESULT: POSSESSION DISTINGUISHES — {d}/{d} forged refused, both held accepted\n", .{ count, count });
    } else {
        std.debug.print("    RESULT: POSSESSION BROKEN\n", .{});
        // The exit contract: a broken run must fail the process, so the
        // harness works as a scriptable gate (CI, status checks) without
        // anything parsing stdout. Exit 0 is the holds verdict, exit 1 is
        // possession broken.
        std.process.exit(1);
    }
}

tor drive { br: *std/bridge:Bridge }
drive = hammer(br, n: 900)

[with]std/bridge:create(id: "possession-distinct", scope: "notes"): br
|> drive(br)