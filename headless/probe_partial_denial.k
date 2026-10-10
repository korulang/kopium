// PROBE, not a deliverable. A multi-item turn keeps running past refusal:
// a denied step is one line in the `?partial` report, not the end of the
// turn — the model learns every step's outcome in one observation. This
// probe drives a deny → run → deny turn through the same `std/bridge:run`
// the live path calls, canned: no network, no model, no spend.
//
//   koruc probe_partial_denial.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-partial-denial", scope: "notes"): br
|> std/io:print.ln("--- wire law: refusal mid-turn is a step, not a stop ---")
|> deny-run-deny(br)
|> survives(br)
|> std/io:print.ln("--- done ---")

// 1. deny, run, deny: the middle step still runs, and the report names
// each step's verdict — event-denied is a line, not a turn-verdict.
tor deny-run-deny { br: *std/bridge:Bridge<session> }
deny-run-deny = app/wire:clean(raw: "delete(path: \"a\")\nsay(text: \"middle ran\")\ndelete(path: \"b\")")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> report(br, source: src.text)
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean failed: {{ e:s }} — WRONG, clean keeps the whole turn")

tor report { br: *std/bridge:Bridge<session>, source: string }
report = std/bridge:run(br, source)
| partial p |> std/io:print.ln("partial {{ p.ran:d }}/{{ p.total:d }}\n{{ p.report:s }}")
| result r |> std/io:print.ln("WRONG: result handles={{ r.handles:d }} — a three-item turn is not a single result")
| defined d |> std/io:print.ln("WRONG: defined {{ d:s }}")
| unhandled-branch ub |> std/io:print.ln("WRONG: unhandled {{ ub.branch:s }} — the whole turn is not one branch")
| dispatch-error e |> std/io:print.ln("WRONG: refused {{ e.event_name:s }}: {{ e.message:s }} — a denied step is not a turn refusal")
| event-denied ev |> std/io:print.ln("WRONG: denied {{ ev:s }} — a multi-item turn reports per step, it does not deny the turn")
| residue r |> std/io:print.ln("RESIDUE {{ r.report:s }}")
| parse-error p |> std/io:print.ln("WRONG: parse-error {{ p.message:s }}")
| exhausted _ |> std/io:print.ln("WRONG: exhausted")
| validation-error v |> std/io:print.ln("WRONG: invalid {{ v:s }}")
| shape-error sh |> std/io:print.ln("WRONG: shape {{ sh.message:s }}")
| scope-not-found s2 |> std/io:print.ln("WRONG: no scope {{ s2:s }}")

// 2. The session outlives the denials: the next single-item turn runs.
tor survives { br: *std/bridge:Bridge<session> }
survives = std/io:print.ln("--- the bridge survives the denials ---")
    |> std/bridge:run(br, source: "say(text: \"still here after two denials\")")
    | result r |> std/io:print.ln("say ran — bridge holds {{ r.handles:d }} resource(s)")
    | partial p |> std/io:print.ln("WRONG: partial on a one-item turn")
    | unhandled-branch ub |> std/io:print.ln("WRONG: unhandled {{ ub.branch:s }}")
    | defined d |> std/io:print.ln("WRONG: defined {{ d:s }}")
    | dispatch-error e |> std/io:print.ln("WRONG: refused {{ e.message:s }}")
    | event-denied ev |> std/io:print.ln("WRONG: denied {{ ev:s }}")
    | residue r |> std/io:print.ln("RESIDUE {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("WRONG: parse-error {{ p.message:s }}")
    | exhausted _ |> std/io:print.ln("WRONG: exhausted")
    | validation-error v |> std/io:print.ln("WRONG: invalid {{ v:s }}")
    | shape-error sh |> std/io:print.ln("WRONG: shape {{ sh.message:s }}")
    | scope-not-found s2 |> std/io:print.ln("WRONG: no scope {{ s2:s }}")
