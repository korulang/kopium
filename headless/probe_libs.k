// PROBE, not a deliverable. The libs workbench scope, canned: file verbs
// resolve under LIBS_ROOT (escapes refused at the module, not by asking
// the model to behave), the toolchain verbs shell real koruc, and every
// verdict is a branch the wire can name. No network, no model, no spend.
//
//   koruc probe_libs.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/libs
import app/wire

[with]std/bridge:create(id: "probe-libs", scope: "libs"): br
|> std/io:print.ln("--- libs workbench, canned ---")
|> file-verbs(br)
|> toolchain-verbs(br)
|> std/io:print.ln("--- done ---")

tor file-verbs { br: *std/bridge:Bridge }
file-verbs = std/bridge:run(br, source: "read(path: \"gzip/index.kz\") | ok t |> say(text: \"read hit\")\nread(path: \"nope.kz\") | ok t |> say(text: \"BAD\") | missing m |> say(text: \"missing arm fired\")\nread(path: \"../koru/README.md\") | ok t |> say(text: \"ESCAPE — BAD\") | denied d |> say(text: \"denied arm fired\")\nwrite(path: \"probe_scratch.tmp\", text: \"before\") | ok w |> say(text: \"wrote\")\nedit(path: \"probe_scratch.tmp\", old_text: \"before\", new_text: \"after\") | ok e |> say(text: \"edited\") | mismatch m |> say(text: \"BAD mismatch\")\nread(path: \"probe_scratch.tmp\") | ok t |> say(text: t)\nwrite(path: \"probe_escape.tmp\", text: \"line one\\nline two\") | ok w |> say(text: \"escapes written\")\nread(path: \"probe_escape.tmp\") | ok t |> say(text: t)")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")
| result r |> std/io:print.ln("result")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| defined d |> std/io:print.ln("defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("exhausted")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no scope: {{ s:s }}")

tor toolchain-verbs { br: *std/bridge:Bridge }
toolchain-verbs = std/bridge:run(br, source: "check(path: \"gzip/tests/roundtrip.kz\") | ok |> say(text: \"check green\") | error e |> say(text: e)\ntest(path: \"sqlite3/tests/basic.k\") | pass |> say(text: \"test pass\") | fail f |> say(text: f)\nboard()")
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}:\n{{ p.report:s }}")
| result r |> std/io:print.ln("result")
| unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}]")
| parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }}")
| event-denied ev |> std/io:print.ln("DENIED {{ ev:s }}")
| dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }}")
| defined d |> std/io:print.ln("defined {{ d:s }}")
| exhausted _ |> std/io:print.ln("exhausted")
| validation-error v |> std/io:print.ln("invalid: {{ v:s }}")
| shape-error sh |> std/io:print.ln("shape: {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("no scope: {{ s:s }}")
