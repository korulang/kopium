// PROBE — say's text field (a plain string now) takes a bound name,
// interpolates {{ name }} / {{ name.field }}, refuses unbound names, and
// passes literal braces through. The "colon-form" row is the deleted
// spelling in chain-step position — it should stay silent (cataloged
// swallow, 2026-10-18-colon-in-chain) until the step parser refuses it.
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

[with]std/bridge:create(id: "say-field", scope: "notes", world: "arm-world"): br
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n| ok t |> say(text: t)", tag: "bound-value")
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n| ok t |> say(text: \"file says: {{ t }}\")", tag: "interpolated")
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n| ok t |> say: the file held {{ t }}", tag: "colon-form")
|> holdrun(br, source: "read(path: \"arm-say.txt\")\n| ok t |> say(text: \"unbound {{ nowhere.x }} should refuse\")", tag: "unbound")
|> holdrun(br, source: "say(text: \"literal braces {{ not-a-name? }} pass through\")", tag: "literal-brace")
|> std/bridge:close(br)
|> std/io:print.ln("[closed]")
