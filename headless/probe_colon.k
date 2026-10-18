// PROBE — the one-spelling wire: `verb:` colon lines refuse as residue
// (bare-colon, colon-nobrace, colon-interp rows) while canonical
// verb(field: "...") dispatch, {{ }} interpolation, and failure-arm
// say all still fire. The chain-step `|> say: x` swallow is the
// cataloged gap — challenges/bridge-mirror/2026-10-18-colon-in-chain.md.
import std/bridge
import std/io
import app/notes

tor holdrun { br: *std/bridge:Bridge<session>, source: string, tag: string }
holdrun = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial")
| unhandled-branch ub |> std/io:print.ln("[{{ tag:s }}] unhandled {{ ub.branch:s }}")
| parse-error e |> std/io:print.ln("[{{ tag:s }}] parse-error {{ e.message:s }}")
| validation-error v |> std/io:print.ln("[{{ tag:s }}] validation-error {{ v:s }}")
| event-denied d |> std/io:print.ln("[{{ tag:s }}] event-denied {{ d:s }}")
| dispatch-error e |> std/io:print.ln("[{{ tag:s }}] dispatch-error {{ e.message:s }}")
| exhausted e |> std/io:print.ln("[{{ tag:s }}] exhausted")
| residue r2 |> std/io:print.ln("[{{ tag:s }}] residue")
| shape-error s |> std/io:print.ln("[{{ tag:s }}] shape-error")
| scope-not-found s |> std/io:print.ln("[{{ tag:s }}] scope-not-found")
| defined d2 |> std/io:print.ln("[{{ tag:s }}] defined")

[with]std/bridge:create(id: "colon", scope: "notes", world: "arm-world"): br
|> holdrun(br, source: "say: hello colon world", tag: "bare-colon")
|> holdrun(br, source: "read(path: \"arm-say.txt\") | ok t |> say(text: \"chain paren says {{ t }}\")", tag: "chain-paren")
|> holdrun(br, source: "read(path: \"arm-say.txt\") | ok t |> say: plain colon no braces", tag: "colon-nobrace")
|> holdrun(br, source: "read(path: \"arm-say.txt\") | ok t |> say: the file held {{ t }}", tag: "colon-interp")
|> holdrun(br, source: "read(path: \"nope.txt\") | ok t |> say(text: \"wont see\") | missing m |> say(text: \"gone: {{ m }}\")", tag: "fail-arm")
|> holdrun(br, source: "read(path: \"arm-say.txt\") | ok a |> say(text: \"one {{ a }} and two {{ a }}\")", tag: "multi")
|> std/bridge:close(br)
|> std/io:print.ln("[closed]")
