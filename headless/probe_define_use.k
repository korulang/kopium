// PROBE, not a deliverable. The flip's payoff for growth: define a verb and
// USE it in the same turn. Under the old wire a `tor ` declaration was its own
// turn (the second invocation was truncated), so define→use always cost two
// turns. The sequencing path shares the session's defined table across items,
// so a define item followed by a dispatch item runs and reports as one turn.
// Canned: no network, no model, no spend.
//
//   koruc probe_define_use.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-define-use", scope: "notes"): br
|> std/io:print.ln("--- define and use in one turn ---")
|> go(br)
|> std/io:print.ln("--- done ---")

tor go { br: *std/bridge:Bridge }
go = app/wire:clean(raw: "tor greet { msg: string }\ngreet = say(text: msg)\ngreet(msg: \"hello from the same turn\")")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> std/io:print.ln("cleaned> [{{ src.text:s }}]")
    |> report(br, source: src.text)
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean err: {{ e:s }}")

tor report { br: *std/bridge:Bridge, source: string }
report = std/bridge:run(br, source)
| partial p |> std/io:print.ln("PARTIAL {{ p.ran:d }}/{{ p.total:d }} report=[{{ p.report:s }}]")
| result r |> std/io:print.ln("WRONG: result handles={{ r.handles:d }} — define+use is two items")
| defined d |> std/io:print.ln("WRONG: defined {{ d:s }} — the call after the define did not run")
| unhandled-branch ub |> std/io:print.ln("WRONG: unhandled {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("WRONG: refused {{ e.event_name:s }}: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("WRONG: denied {{ ev:s }} — the definition was not in scope for the next item")
| parse-error p |> std/io:print.ln("WRONG: parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("WRONG: exhausted")
| validation-error v |> std/io:print.ln("WRONG: invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("WRONG: shape {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("WRONG: no scope {{ s2:s }}")
