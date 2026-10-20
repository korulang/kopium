// Zero-token probe: THE RULING (Lars 2026-09-07/08) — freshly minted handles
// are OPAQUE. Not `note_N`, not sequential, not guessable: a handle you do
// not hold is a handle you cannot name. The only legal access is binding —
// capture what the observation returned — or the refusal.
//
// The mint is `app/notes:open`. `last-minted` is the inspection seam the
// session and probes use to read what the module just minted (the live agent
// never needs it — it reads observations). This probe:
//
//   A  open -> the minted handle is 6 lowercase hex, not "note_"
//   B  open again -> a DIFFERENT handle (nothing sequential to predict)
//   C  append with the minted handle -> binds (the real one works)
//   D  close with the minted handle -> binds
//   E  a fabricated 6-hex guess -> REFUSED (never minted)
//
// The same ruling reached the interpreter pool (interpreter.pool.kz,
// 2026-10-20): `*T` resource tokens mint `h:Type:xxxxxx` — type legible,
// hex unpredictable. Before that, `h:Connection:2` was a real handle a
// program could fabricate by counting.
//
//   F  open-db twice -> two `h:Connection:` tokens, distinct seeded hex
//   G  `h:Connection:2` (the old sequence) and `h:Connection:ffffff`
//      (a fabricated guess) -> both REFUSED
//
//   koruc probe_opaque_handles.k && ./a.out

import std/io
import std/bridge
import std/fmt
import std/string
import std/interpreter
import app/notes
import app/db_scope

tor mint-1 { br: *std/bridge:Bridge<session> }
mint-1 = std/io:print.ln("--- A: first open mints an opaque handle ---")
    |> std/bridge:run(br, source: "open(path: \"probe_opaque_1.txt\")")
    | result r |> std/io:print.ln("mint-1 ran") |> app/notes:last-minted(): h1 |> std/io:print.ln("minted-1: {{ h1:s }}")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("EXHAUSTED")
    | validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")

tor mint-2 { br: *std/bridge:Bridge<session> }
mint-2 = std/io:print.ln("--- B: a second open mints a DIFFERENT handle ---")
    |> std/bridge:run(br, source: "open(path: \"probe_opaque_2.txt\")")
    | result r |> std/io:print.ln("mint-2 ran") |> app/notes:last-minted(): h2 |> std/io:print.ln("minted-2: {{ h2:s }}")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("EXHAUSTED")
    | validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")

tor append-wire { handle: string } -> string<std/io:allocated!>
append-wire = std/fmt:fmt.blk {
        append(handle: "{{ handle:s }}", text: "bound")
    }: m -> m

tor close-wire { handle: string } -> string<std/io:allocated!>
close-wire = std/fmt:fmt.blk {
        close(handle: "{{ handle:s }}")
    }: m -> m

tor bind-append { br: *std/bridge:Bridge<session> }
bind-append = std/io:print.ln("--- C: the minted handle is the one that binds ---")
    |> app/notes:last-minted(): h
    |> append-wire(handle: h): src
    |> pool-run(br, source: src, tag: "append-bound")

tor bind-close { br: *std/bridge:Bridge<session> }
bind-close = std/io:print.ln("--- D: close binds with the same handle ---")
    |> app/notes:last-minted(): h
    |> close-wire(handle: h): src
    |> pool-run(br, source: src, tag: "close-bound")

tor guess { br: *std/bridge:Bridge<session> }
guess = std/io:print.ln("--- E: a fabricated 6-hex guess is refused ---")
    |> std/bridge:run(br, source: "close(handle: \"deadbe\")")
    | result r |> std/io:print.ln("result — WRONG, deadbe was never minted")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("refused: {{ e.message:s }} — deadbe was never minted")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("EXHAUSTED")
    | validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")

// The pool-mint half of the wall: tokens from `*T` resource returns ride
// `mintResourceToken`, not the notes mint — same ruling, second site.
tor pool-run { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
pool-run = std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): v |> std/io:print.ln("{{ tag:s }}: {{ v:s }}")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| defined d |> std/io:print.ln("DEFINED {{ d:s }}")
| dispatch-error e |> std/io:print.ln("{{ tag:s }} refused: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| residue r |> std/io:print.ln("RESIDUE: {{ r.report:s }}")
| parse-error p |> std/io:print.ln("PARSE ERROR: {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("EXHAUSTED")
| validation-error v |> std/io:print.ln("INVALID: {{ v:s }}")
| shape-error sh |> std/io:print.ln("SHAPE ERROR: {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("NO SCOPE: {{ s2:s }}")
| partial p |> std/io:print.ln("partial:\n{{ p.report:s }}")

tor pool-mint { br: *std/bridge:Bridge<session> }
pool-mint = std/io:print.ln("--- F: pool resource tokens are seeded hex ---")
    |> pool-run(br, source: "open-db(path: \"probe_opaque_pool.db\") | db c |>", tag: "minted-1")
    |> pool-run(br, source: "open-db(path: \"probe_opaque_pool2.db\") | db c |>", tag: "minted-2")

tor pool-guess { br: *std/bridge:Bridge<session> }
pool-guess = std/io:print.ln("--- G: sequential and fabricated pool guesses are refused ---")
    |> pool-run(br, source: "close-db(conn: \"h:Connection:2\")", tag: "seq-guess")
    |> pool-run(br, source: "close-db(conn: \"h:Connection:ffffff\")", tag: "hex-guess")

[with]std/bridge:create(id: "probe-opaque-handles", scope: "notes"): br
|> mint-1(br) |> mint-2(br) |> bind-append(br) |> bind-close(br) |> guess(br)

[with]std/bridge:create(id: "probe-opaque-pool", scope: "db"): br2
|> pool-mint(br: br2) |> pool-guess(br: br2)
