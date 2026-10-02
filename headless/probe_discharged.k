// PROBE, not a deliverable. The discharged-handle defect, measured and
// settled: a model chains `open | ok h |> append(handle: h) | ok |> close`
// reading it as a nested chain — but flat `|` lines are SIBLING arms on the
// head call, and arm selection is first-match, so the second `ok` arm never
// fires. The close sat in dead text: `result` verdict, handle held, note
// open — the live session's `alpha\nalpha` corruption.
//
// Settled koru-side (a01abb341): `checkShadowedArms` refuses the second
// unguarded same-branch terminal arm at validation — the mirror of
// SHAPE002's firstDuplicateSibling — and the message teaches the indented
// nesting spelling. Pinned by koru `440_027`.
//
//   1  the model's line verbatim — refused: unreachable 'ok' arm
//   2  binds h2, still writes flat — same refusal
//   3  the flat "disciplined" chain — refused too (it was never a chain)
//   4  the indented spelling — arm nested under the step — runs, handles=0
//
//   koruc probe_discharged.k && ./a.out
import std/io
import std/fmt
import std/bridge
import app/notes

tor report { br: *std/bridge:Bridge, source: string, tag: string }
report = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result handles={{ r.handles:d }}")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial {{ p.ran:d }}/{{ p.total:d }} handles={{ p.handles:d }}")
| defined d |> std/io:print.ln("[{{ tag:s }}] defined {{ d:s }}")
| unhandled-branch ub |> std/io:print.ln("[{{ tag:s }}] unhandled-branch {{ ub.branch:s }} held={{ ub.handles:s }}")
| dispatch-error e |> std/io:print.ln("[{{ tag:s }}] dispatch-error {{ e.event_name:s }}: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("[{{ tag:s }}] event-denied {{ ev:s }}")
| residue r |> std/io:print.ln("[{{ tag:s }}] residue {{ r.report:s }}")
| parse-error p |> std/io:print.ln("[{{ tag:s }}] parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("[{{ tag:s }}] exhausted")
| validation-error v |> std/io:print.ln("[{{ tag:s }}] validation-error {{ v:s }}")
| shape-error sh |> std/io:print.ln("[{{ tag:s }}] shape-error {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("[{{ tag:s }}] scope-not-found {{ s2:s }}")

tor defect-verbatim { br: *std/bridge:Bridge }
defect-verbatim = std/io:print.ln("--- 1: the model's line — close the pre-append binding ---")
|> report(br, source: "open(path: \"probe_discharged_a.txt\")\n| ok h |> append(handle: h, text: \"alpha\")\n| ok |> close(handle: h)", tag: "verbatim")

tor aliased { br: *std/bridge:Bridge }
aliased = std/io:print.ln("--- 2: binds h2, still closes h — then uses h2 ---")
|> report(br, source: "open(path: \"probe_discharged_b.txt\")\n| ok h |> append(handle: h, text: \"beta\")\n| ok h2 |> close(handle: h)", tag: "aliased-close")
|> report(br, source: "open(path: \"probe_discharged_c.txt\")\n| ok h |> append(handle: h, text: \"gamma\")\n| ok h2 |> append(handle: h2, text: \"after-close\")\n| ok |> close(handle: h2)", tag: "h2-after-close")

tor flat-rebind { br: *std/bridge:Bridge }
flat-rebind = std/io:print.ln("--- 3: flat chain with the re-bind — still refused ---")
|> report(br, source: "open(path: \"probe_discharged_d.txt\")\n| ok h |> append(handle: h, text: \"delta\")\n| ok h2 |> close(handle: h2)", tag: "flat-rebind")

tor nested { br: *std/bridge:Bridge }
nested = std/io:print.ln("--- 4: the indented spelling — arm nested under the step ---")
|> report(br, source: "open(path: \"probe_discharged_e.txt\")\n| ok h |> append(handle: h, text: \"epsilon\")\n    | ok h2 |> close(handle: h2)", tag: "nested")

[with]std/bridge:create(id: "probe-discharged", scope: "notes"): br
|> defect-verbatim(br) |> aliased(br) |> flat-rebind(br) |> nested(br)
|> std/io:print.ln("--- done ---")
