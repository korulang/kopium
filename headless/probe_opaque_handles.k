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
//   koruc probe_opaque_handles.k && ./a.out

import std/io
import std/bridge
import std/fmt
import app/notes

tor mint-1 { br: *std/bridge:Bridge }
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

tor mint-2 { br: *std/bridge:Bridge }
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

tor bind-append { br: *std/bridge:Bridge }
bind-append = std/io:print.ln("--- C: the minted handle is the one that binds ---")
    |> app/notes:last-minted(): h
    |> std/fmt:ln("append(handle: \"{{ h:s }}\", text: \"bound\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("append-bound: ok — holds {{ r.handles:d }} resource(s)")
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

tor bind-close { br: *std/bridge:Bridge }
bind-close = std/io:print.ln("--- D: close binds with the same handle ---")
    |> app/notes:last-minted(): h
    |> std/fmt:ln("close(handle: \"{{ h:s }}\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("close-bound: ok — holds {{ r.handles:d }} resource(s)")
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

tor guess { br: *std/bridge:Bridge }
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

[with]std/bridge:create(id: "probe-opaque-handles", scope: "notes"): br
|> mint-1(br) |> mint-2(br) |> bind-append(br) |> bind-close(br) |> guess(br)
