// PROBE, not a deliverable. The third vocabulary: `calc` has no handles —
// names and branch payloads are the only names in the domain. Every turn
// asks the same question — did this DERIVE from the register block, or was
// it secretly possession-shaped?
//
//   1  the derived vocabulary lists calc's verbs
//   2  the derived grammar renders — read it for handle language
//   3  add binds the `sum` payload — the binding discipline, minus handles
//   4  div by zero -> by-zero arm fires with a payload, nothing held
//   5  add with a non-integer -> bad-input arm, handled refusal
//   6  arm body referencing an unbound name -> validation-error naming it
//   7  a notes verb and a ledger verb -> event-denied at the wall
//   8  an invented field on add -> validation-error (derived, third vocab)
//   9  remember/recall: world state crosses items even though bindings
//      cannot — item 1 stores, item 2 reads by name
//  10  define through run + a call -> growth is per-scope
//
//   koruc probe_calc.k && ./a.out
import std/io
import std/fmt
import std/bridge
import app/calc

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

tor vocab { br: *std/bridge:Bridge }
vocab = std/io:print.ln("--- 1: derived vocabulary (calc register only) ---")
|> std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found s |> std/io:print.ln("WRONG: no scope {{ s:s }}")

tor grammar { br: *std/bridge:Bridge }
grammar = std/io:print.ln("--- 2: derived grammar (does it teach handles?) ---")
|> std/bridge:grammar(br)
| ok g |> std/io:print.ln("{{ g:s }}")
| not-found s |> std/io:print.ln("WRONG: no scope {{ s:s }}")

tor add-ok { br: *std/bridge:Bridge }
add-ok = std/io:print.ln("--- 3: add binds the sum payload ---")
|> report(br, source: "add(a: \"2\", b: \"40\")\n| sum s |> say(text: s)\n| bad-input m |> say(text: \"WRONG-bad\")", tag: "add-ok")

tor div-zero { br: *std/bridge:Bridge }
div-zero = std/io:print.ln("--- 4: div by zero -> by-zero with payload ---")
|> report(br, source: "div(a: \"7\", b: \"0\")\n| quotient q |> say(text: \"WRONG-q\")\n| by-zero m |> say(text: m)", tag: "div-zero")

tor add-bad { br: *std/bridge:Bridge }
add-bad = std/io:print.ln("--- 5: add on a non-integer -> bad-input, handled ---")
|> report(br, source: "add(a: \"fifty\", b: \"1\")\n| sum s |> say(text: \"WRONG-sum\")\n| bad-input m |> say(text: m)", tag: "add-bad")

tor unbound { br: *std/bridge:Bridge }
unbound = std/io:print.ln("--- 6: arm body names `t`, only `s` is bound -> validation-error ---")
|> report(br, source: "add(a: \"1\", b: \"2\")\n| sum s |> say(text: t)", tag: "unbound")

tor denied { br: *std/bridge:Bridge }
denied = std/io:print.ln("--- 7: notes and ledger verbs on calc scope -> event-denied ---")
|> report(br, source: "open(path: \"x.txt\")", tag: "denied-notes")
|> report(br, source: "open-acct(name: \"savings\")", tag: "denied-ledger")

tor foreign { br: *std/bridge:Bridge }
foreign = std/io:print.ln("--- 8: invented field on add -> validation-error ---")
|> report(br, source: "add(a: \"1\", b: \"2\", bogus: \"x\")", tag: "foreign")

tor memory { br: *std/bridge:Bridge }
memory = std/io:print.ln("--- 9: world state crosses items (bindings cannot) ---")
|> report(br, source: "remember(name: \"x\", value: \"7\")\nrecall(name: \"x\")\n| ok v |> say(text: v)\n| missing m |> say(text: \"WRONG-missing\")", tag: "memory")
|> report(br, source: "recall(name: \"ghost\")\n| ok v |> say(text: \"WRONG-ok\")\n| missing m |> say(text: m)", tag: "memory-miss")

tor growth { br: *std/bridge:Bridge }
growth = std/io:print.ln("--- 10: define through run, then call it ---")
|> report(br, source: "tor shout { msg: string }\nshout = say(text: msg)", tag: "define")
|> report(br, source: "shout(msg: \"growth carried to calc\")", tag: "call")

[with]std/bridge:create(id: "probe-calc", scope: "calc"): br
|> vocab(br) |> grammar(br) |> add-ok(br) |> div-zero(br) |> add-bad(br)
|> unbound(br) |> denied(br) |> foreign(br) |> memory(br) |> growth(br)
|> std/io:print.ln("--- done ---")
