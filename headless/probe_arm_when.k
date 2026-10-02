// PROBE, not a deliverable. bridge-mirror row: arm-level `when` guards.
// The compiled surface honors `| branch b when <expr> |>` (guarded arm is
// skipped when the guard is false, control falls to the next matching arm).
// flow_parser stores the guard as cont.condition; the question is whether
// (a) the wire lets the arm line through at all, and (b) the interpreter
// evaluates it — `when false` MUST NOT fire its body.
//
//   koruc probe_arm_when.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-arm-when", scope: "notes"): br
|> std/io:print.ln("--- arm-level when: false guard must not fire ---")
|> when-false(br)
|> std/io:print.ln("--- arm-level when: true guard fires ---")
|> when-true(br)
|> std/io:print.ln("--- done ---")

tor when-false { br: *std/bridge:Bridge }
when-false = app/wire:clean(raw: "read(path: \"probe_multiline.k\")\n| ok t when false |> say(text: \"FIRED-despite-false-guard\")\n| ok u |> say(text: \"unguarded-arm-ran\")\n| missing m |> say(text: \"WRONG-missing\")")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> report(br, source: src.text, tag: "when-false")
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean failed: {{ e:s }}")

tor when-true { br: *std/bridge:Bridge }
when-true = app/wire:clean(raw: "read(path: \"probe_multiline.k\")\n| ok t when true |> say(text: \"true-guard-fired\")\n| ok u |> say(text: \"WRONG-unguarded-ran\")\n| missing m |> say(text: \"WRONG-missing\")")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> report(br, source: src.text, tag: "when-true")
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean failed: {{ e:s }}")

tor report { br: *std/bridge:Bridge, source: string, tag: string }
report = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result handles={{ r.handles:d }}")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial {{ p.ran:d }}/{{ p.total:d }}")
| defined d |> std/io:print.ln("[{{ tag:s }}] defined {{ d:s }}")
| unhandled-branch ub |> std/io:print.ln("[{{ tag:s }}] unhandled-branch {{ ub.branch:s }}")
| dispatch-error e |> std/io:print.ln("[{{ tag:s }}] dispatch-error {{ e.event_name:s }}: {{ e.message:s }}")
| event-denied ev |> std/io:print.ln("[{{ tag:s }}] event-denied {{ ev:s }}")
| residue r |> std/io:print.ln("[{{ tag:s }}] residue {{ r.report:s }}")
| parse-error p |> std/io:print.ln("[{{ tag:s }}] parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("[{{ tag:s }}] exhausted")
| validation-error v |> std/io:print.ln("[{{ tag:s }}] validation-error {{ v:s }}")
| shape-error sh |> std/io:print.ln("[{{ tag:s }}] shape-error {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("[{{ tag:s }}] scope-not-found {{ s2:s }}")
