// Repro of the MISSING DIAGNOSTIC that anchored this hole: `=>` inside a
// `! query` sweep arm constructs a branch the void sweepbody cannot hold.
// The non-sweep sibling (`! beat _ => ran`) is pinned in koru by
// 400_199_reject_construct_glyph_on_void_effect; THIS variant is pinned by
// 690_357_construct_glyph_in_query_arm plus its sibling pins 690_358/59/60
// (interceptor / watch / rule arms). The store transforms refuse KORU102
// pre-graft via refuseUncrossable (koru_std/store.uncrossable.kz) —
// see HOLE.md.
//
// Build: koruc probe.k
// Result 2026-10-03: error[KORU102] — "std/store:query(box): `=>` inside a
//   `! query` arm has nothing to construct ..." — no emitted-Zig death.
import std/io
import std/store

std/store:new(box, capacity: 4) { n: i64, m: i64 }

tor work {}
| ran
| rejected

work = std/store:query(box)
! query e |> std/io:print.ln("row {{ e.n:d }}") => ran

std/store:insert(box) { n: 1, m: 2 }
| row _ |> work()
    | ran |> std/io:print.ln("RAN")
    | rejected |> std/io:print.ln("REJ")
| full |> std/io:print.ln("FULL")
