// PROBE — arm shapes on the wire. read has two branches (ok/missing).
// Receipts: inline `|` arms all bind the HEAD call (never an interior
// step); indented `|` lines arm by indent — deeper indent arms a
// mid-chain step; a `|` on the call's own line commits the program to
// that line, so a later indented arm refuses as a parse-error.
import std/bridge
import std/io
import app/notes

tor holdrun { br: *std/bridge:Bridge<session>, source: string, tag: string }
holdrun = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial {{ p.report:s }}")
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

// 1. inline multi-branch on one line — does `missing` arm read or say?
//    (missing input: read fails -> which arm fires?)
[with]std/bridge:create(id: "ml", scope: "notes", world: "arm-world"): br
|> holdrun(br, source: "read(path: \"nope.txt\") | ok t |> say(text: \"ok {{ t }}\") | missing m |> say(text: \"miss {{ m }}\")", tag: "inline-2arm-miss")
|> holdrun(br, source: "read(path: \"arm-say.txt\") | ok t |> say(text: \"ok {{ t }}\") | missing m |> say(text: \"miss {{ m }}\")", tag: "inline-2arm-ok")
|> holdrun(br, source: "read(path: \"nope.txt\")\n    | ok t |> say(text: \"ok {{ t }}\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "ml-2arm-miss")
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n    | ok t |> say(text: \"ok {{ t }}\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "ml-2arm-ok")
|> holdrun(br, source: "read(path: \"nope.txt\") | ok t |> say(text: \"ok {{ t }}\")\n    | missing m |> say(text: \"miss {{ m }}\")", tag: "mixed-refused")
|> holdrun(br, source: "read(path: \"nope.txt\") | ok t |> hush() | missing m |> say(text: \"miss {{ m }}\")", tag: "inline-nest")
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n    | ok t |> read(path: t)\n        | ok t2 |> say(text: \"inner ok\")\n        | missing m2 |> say(text: \"inner miss\")\n    | missing m |> say(text: \"outer miss {{ m }}\")", tag: "ml-interior-inner")
|> holdrun(br, source: "read(path: \"nope.txt\")\n    | ok t |> read(path: t)\n        | ok t2 |> say(text: \"inner ok\")\n        | missing m2 |> say(text: \"inner miss\")\n    | missing m |> say(text: \"outer miss {{ m }}\")", tag: "ml-interior-outer")
