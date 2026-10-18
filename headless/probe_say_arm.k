// PROBE — the armed say: does say() fire conditioned inside a chain's arm,
// and does the failure arm's say fire instead when the branch differs?
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

[with]std/bridge:create(id: "arm-say", scope: "notes", world: "arm-world"): br
|> std/io:print.ln("--- armed-ok: open | ok h |> say |> close ---")
|> holdrun(br, source: "open(path: \"arm-say.txt\")\n| ok h |> say(text: \"opened fine\")\n    |> close(handle: h)", tag: "armed-ok")
|> std/io:print.ln("--- armed-fail: read missing | ok |> say(no) | not-found |> say(yes) ---")
|> holdrun(br, source: "read(path: \"definitely-missing-xyz.txt\")\n| ok t |> say(text: \"should not fire\")\n| missing |> say(text: \"it was not there\")", tag: "armed-fail")
|> std/bridge:close(br)
|> std/io:print.ln("[closed]")
