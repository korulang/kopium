// PROBE, not a deliverable. The fanout experiment's composed-1 turn 1: the
// model emitted all three files' work in ONE reply — three items, each a
// flat `open | ok h |> append | ok a |> close` chain — and the verdict was
// `steps: 3/3 ran, bridge holds 0` while every file read `missing`.
// Reproduce that turn verbatim and measure what actually ran.
//
//   koruc probe_fanout.k && ./a.out
import std/io
import std/fmt
import std/bridge
import app/notes

tor report { br: *std/bridge:Bridge, source: string, tag: string }
report = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result handles={{ r.handles:d }}")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial {{ p.ran:d }}/{{ p.total:d }} handles={{ p.handles:d }}\n{{ p.report:s }}")
| defined d |> std/io:print.ln("[{{ tag:s }}] defined {{ d:s }}")
| unhandled-branch ub |> std/io:print.ln("[{{ tag:s }}] unhandled-branch {{ ub.branch:s }} held={{ ub.handles:s }}")
| dispatch-error e |> std/io:print.ln("[{{ tag:s }}] dispatch-error {{ e.event_name:s }}: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("[{{ tag:s }}] event-denied {{ ev:s }}")
| parse-error p |> std/io:print.ln("[{{ tag:s }}] parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("[{{ tag:s }}] exhausted")
| validation-error v |> std/io:print.ln("[{{ tag:s }}] validation-error {{ v:s }}")
| shape-error sh |> std/io:print.ln("[{{ tag:s }}] shape-error {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("[{{ tag:s }}] scope-not-found {{ s2:s }}")

tor check { path: string, tag: string }
check = std/io:read-file(path)
| ok c |> std/io:print.ln("[{{ tag:s }}] disk {{ path:s }} = [{{ c:s }}]") |> std/io:free(content: c)
| not-found |> std/io:print.ln("[{{ tag:s }}] disk {{ path:s }} = missing")
| failed e |> std/io:print.ln("[{{ tag:s }}] disk {{ path:s }} = failed {{ e:s }}")

tor multi { br: *std/bridge:Bridge }
multi = std/io:print.ln("--- 1: the model's three-item flat-chain turn, verbatim ---")
|> report(br, source: "open(path: \"probe_fan_a.txt\") | ok h1 |> append(handle: h1, text: \"alpha\") | ok a1 |> close(handle: h1)\nopen(path: \"probe_fan_b.txt\") | ok h2 |> append(handle: h2, text: \"beta\") | ok a2 |> close(handle: h2)\nopen(path: \"probe_fan_c.txt\") | ok h3 |> append(handle: h3, text: \"gamma\") | ok a3 |> close(handle: h3)", tag: "three-flat")
|> check(path: "probe_fan_a.txt", tag: "three-flat")
|> check(path: "probe_fan_b.txt", tag: "three-flat")
|> check(path: "probe_fan_c.txt", tag: "three-flat")

tor multi-nested { br: *std/bridge:Bridge }
multi-nested = std/io:print.ln("--- 2: three items, each with the nested spelling ---")
|> report(br, source: "open(path: \"probe_fan_d.txt\")\n| ok h1 |> append(handle: h1, text: \"delta\")\n    | ok a1 |> close(handle: a1)\nopen(path: \"probe_fan_e.txt\")\n| ok h2 |> append(handle: h2, text: \"epsilon\")\n    | ok a2 |> close(handle: a2)\nopen(path: \"probe_fan_f.txt\")\n| ok h3 |> append(handle: h3, text: \"zeta\")\n    | ok a3 |> close(handle: a3)", tag: "three-nested")
|> check(path: "probe_fan_d.txt", tag: "three-nested")
|> check(path: "probe_fan_e.txt", tag: "three-nested")
|> check(path: "probe_fan_f.txt", tag: "three-nested")

tor multi-items { br: *std/bridge:Bridge }
multi-items = std/io:print.ln("--- 3: three plain items, no arms ---")
|> report(br, source: "open(path: \"probe_fan_g.txt\")\nopen(path: \"probe_fan_h.txt\")\nopen(path: \"probe_fan_i.txt\")", tag: "three-plain")
|> check(path: "probe_fan_g.txt", tag: "three-plain")
|> check(path: "probe_fan_h.txt", tag: "three-plain")
|> check(path: "probe_fan_i.txt", tag: "three-plain")

[with]std/bridge:create(id: "probe-fanout", scope: "notes"): br
|> multi(br) |> multi-nested(br) |> multi-items(br)
|> std/io:print.ln("--- done ---")
