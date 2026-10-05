// Zero-token probe: the callsite catch-all is refused at the emitted-source
// boundary — the same `std/bridge:run` the act loop feeds model output to.
//
// frag-the-callsite-cannot-spell-a-residual-case: `|?` is not a branch name;
// the consumer may name a declared branch or omit it. A model that emits
// `|?` must get a `parse-error` turn, not a silent residual handler.
//
//   A  read with a `|?` catch-all arm — must be `parse-error`.
//   B  read with a `|? Audit e` metatype catch-all — same refusal.
//   C  control: named `| ok` / `| missing` arms — completes as `result`.
//
//   koruc probe_catchall.k && ./a.out   (needs probe_ub_exists.txt)

import std/io
import std/bridge
import std/interpreter
import app/notes

tor a { br: *std/bridge:Bridge }
a = std/io:print.ln("--- A: emitted |? catch-all ---")
    |> std/bridge:run(br, source: "read(path: \"probe_ub_exists.txt\")\n| ok |> say(text: \"found\")\n|? |> say(text: \"caught the rest\")")
    | result r |> std/io:print.ln("  A-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  A-UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("  A-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  A-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  A-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  A-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  A-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  A-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  A-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  A-NO SCOPE: {{ s2:s }}")

tor b { br: *std/bridge:Bridge }
b = std/io:print.ln("--- B: emitted |? Audit e metatype catch-all ---")
    |> std/bridge:run(br, source: "read(path: \"probe_ub_exists.txt\")\n| ok |> say(text: \"found\")\n|? Audit e |> say(text: \"metatype caught\")")
    | result r |> std/io:print.ln("  B-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  B-UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("  B-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  B-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  B-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  B-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  B-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  B-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  B-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  B-NO SCOPE: {{ s2:s }}")

tor c { br: *std/bridge:Bridge }
c = std/io:print.ln("--- C: control — named arms only ---")
    |> std/bridge:run(br, source: "read(path: \"probe_ub_exists.txt\")\n| ok v |> say(text: \"found it\")\n| missing m |> say(text: \"absent\")")
    | result r |> std/io:print.ln("  C-RESULT branch=[{{ r.value.branch:s }}]")
    | unhandled-branch ub |> std/io:print.ln("  C-UNHANDLED branch=[{{ ub.branch:s }}]")
    | defined d |> std/io:print.ln("  C-DEFINED {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("  C-REFUSED: {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("  C-DENIED {{ ev:s }}")
    | residue r |> std/io:print.ln("  RESIDUE: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("  C-PARSE ERROR: {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("  C-EXHAUSTED")
    | validation-error v |> std/io:print.ln("  C-INVALID: {{ v:s }}")
    | shape-error sh |> std/io:print.ln("  C-SHAPE ERROR: {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("  C-NO SCOPE: {{ s2:s }}")

[with]std/bridge:create(id: "probe-catchall", scope: "notes"): br
|> a(br) |> b(br) |> c(br)
