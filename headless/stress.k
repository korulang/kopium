// stress.k — run the possession claim N times, in-process, pure Koru.
//
// The claim under test: a run may only act on a resource the session HOLDS.
// `close(handle: "<never-minted>")` must be refused BEFORE the proc runs —
// the proc is the irreversible half. This file proves it at volume: N forged
// handles, N refusals, zero side effects, all inside one compiled Koru
// program. No bench driver, no Python, no network.
//
// Usage:
//   koruc stress.k && ./a.out            # N = 900 (default)
//   ./a.out 5000                        # N = 5000
//
// The loop lives in a |zig proc body — the dialect's one legitimate loop
// construct — and mirrors exactly what std/runtime:run|zig does per call:
// resolve the scope, dispatch the invocation, inspect the outcome. The forged
// handle is never in the pool, so assertHandlesHeld fires and the close proc
// never touches a file.

import std/bridge
import std/io
import app/notes

// ============================================================================
// THE HAMMER — N forged close()s against the notes scope, counting refusals.
// N comes from argv[1] (default 900). Uses the scope's OWN dispatcher + spec
// functions — the exact ones runtime:run resolves — so this is the real
// enforcement, at volume.
// ============================================================================

tor hammer { br: *std/bridge:Bridge }

proc hammer|zig {
    const rt = @import("root").koru_std.koru_runtime;
    const interp = @import("root").koru_std.koru_interpreter;
    const std = @import("std");

    const scope_name = "notes";
    const scope_result = rt.get_scope_event.handler(.{ .name = scope_name });
    const scope = switch (scope_result) {
        .scope => |s| s,
        .not_found => @panic("stress: scope 'notes' not registered"),
    };

    // N from argv[1], default 900. Zero-fill so an unset arg is the default.
    var n: u32 = 900;
    const alloc = std.heap.page_allocator;
    if (std.process.argsAlloc(alloc)) |args| {
        defer std.process.argsFree(alloc, args);
        if (args.len > 1) {
            n = std.fmt.parseInt(u32, args[1], 10) catch 900;
        }
    } else |_| {}

    var refused: u32 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        // A forged handle unique per iteration: the pool never minted it.
        var hbuf: [32]u8 = undefined;
        const handle = std.fmt.bufPrint(&hbuf, "note_{d}", .{i + 1000}) catch unreachable;
        var src_buf: [128]u8 = undefined;
        const src = std.fmt.bufPrint(&src_buf, "close(handle: \"{s}\")", .{handle}) catch unreachable;

        const result = interp.run_event.handler(.{
            .source = src,
            .dispatcher = scope.dispatcher,
            .cost_fn = scope.cost_fn,
            .creates_obligations_fn = scope.creates_obligations_fn,
            .discharges_obligations_fn = scope.discharges_obligations_fn,
            .discharge_event_fn = scope.discharge_event_fn,
            .creates_spec_fn = scope.creates_spec_fn,
            .discharges_spec_fn = scope.discharges_spec_fn,
            .budget = null,
            .handle_pool = null, // no session; the pool simply holds nothing
            .fail_fast = true,
            .scope_name = scope_name,
            .auto_discharge = false,
            .defined = null,
        });

        // HandleNotHeld surfaces as dispatch-error: a refusal counted. ANY
        // other outcome means the forged close got past possession — the bug.
        switch (result) {
            .dispatch_error => {
                if (std.mem.indexOf(u8, result.dispatch_error.message, "HandleNotHeld")) |_| {
                    refused += 1;
                }
            },
            else => {},
        }
    }

    std.debug.print("--- possession stress: {d} forged closes, in-process\n", .{n});
    std.debug.print("    forged handles attempted : {d}\n", .{n});
    std.debug.print("    refused before proc ran  : {d}\n", .{refused});
    if (refused == n) {
        std.debug.print("    RESULT: POSSESSION HOLDS — {d}/{d} refused pre-proc, zero side effects\n", .{ refused, n });
    } else {
        std.debug.print("    RESULT: POSSESSION BROKEN — {d}/{d} slipped through to the proc\n", .{ n - refused, n });
    }
}

// The driver — shaped exactly like session.k: a bridge session, then one
// chained call. `hammer` does not use `br` (it needs no session; the pool
// holds nothing), but threading it keeps the session-lifetime shape intact.
tor drive { br: *std/bridge:Bridge }
drive = hammer(br)

[with]std/bridge:create(id: "possession-stress", scope: "notes"): br
|> drive(br)