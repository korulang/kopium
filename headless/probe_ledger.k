// PROBE, not a deliverable. The parametricity spike: `notes` proved the
// register-block claim once; `ledger` is the second domain vocabulary.
// Every turn below asks the same question — did this DERIVE from the
// register block, or was it secretly notes-shaped?
//
//   1  the derived vocabulary lists ledger's verbs
//   2  open-acct mints an opaque acct handle
//   3  post binds it — consume+reissue, balance 50
//   4  post with a non-integer amount -> bad-amount outcome (phantom
//      branch payload), unhandled -> the hand-back fires
//   5  worth reads by name — ok payload "50"
//   6  worth on an unopened name -> missing
//   7  a fabricated handle -> refused pre-proc
//   8  a notes verb on this scope -> event-denied at the vocabulary wall
//   9  a define through run + a call -> growth is per-scope
//  10  close-acct binds the real handle -> released
//
//   koruc probe_ledger.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/ledger

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
vocab = std/io:print.ln("--- 1: derived vocabulary (ledger register only) ---")
|> std/bridge:vocabulary(br)
| ok v |> std/io:print.ln("{{ v:s }}")
| not-found s |> std/io:print.ln("WRONG: no scope {{ s:s }}")

tor open { br: *std/bridge:Bridge }
open = std/io:print.ln("--- 2: open-acct mints ---")
|> report(br, source: "open-acct(name: \"checking\")", tag: "open")

tor post-ok { br: *std/bridge:Bridge }
post-ok = std/io:print.ln("--- 3: post binds the minted handle, ok arm HANDLED ---")
|> app/ledger:last-minted(): h
|> std/fmt:ln("post(handle: \"{{ h:s }}\", amount: \"50\")\n| ok h2 |> say(text: h2)"): src
|> report(br, source: src.text, tag: "post-ok")

tor post-bad { br: *std/bridge:Bridge }
post-bad = std/io:print.ln("--- 4: post with a non-integer amount -> bad-amount, no arm -> hand-back ---")
|> app/ledger:last-minted(): h
|> std/fmt:ln("post(handle: \"{{ h:s }}\", amount: \"fifty\")"): src
|> report(br, source: src.text, tag: "post-bad")

tor worth-ok { br: *std/bridge:Bridge }
worth-ok = std/io:print.ln("--- 5: worth reads the balance by name ---")
|> report(br, source: "worth(name: \"checking\")\n| ok w |> say(text: w)\n| missing m |> say(text: \"WRONG-missing\")", tag: "worth-ok")

tor worth-miss { br: *std/bridge:Bridge }
worth-miss = std/io:print.ln("--- 6: worth on an unopened name -> missing ---")
|> report(br, source: "worth(name: \"ghost\")\n| ok w |> say(text: w)\n| missing m |> say(text: \"no such account\")", tag: "worth-miss")

tor forged { br: *std/bridge:Bridge }
forged = std/io:print.ln("--- 7: fabricated handle refused pre-proc ---")
|> report(br, source: "post(handle: \"deadbe\", amount: \"1\")", tag: "forged")

tor denied { br: *std/bridge:Bridge }
denied = std/io:print.ln("--- 8: a notes verb on ledger scope -> event-denied ---")
|> report(br, source: "open(path: \"x.txt\")", tag: "denied")

tor growth { br: *std/bridge:Bridge }
growth = std/io:print.ln("--- 9: define through run, then call it ---")
|> report(br, source: "tor announce { msg: string }\nannounce = say(text: msg)", tag: "define")
|> report(br, source: "announce(msg: \"growth carried to ledger\")", tag: "call")

tor close { br: *std/bridge:Bridge }
close = std/io:print.ln("--- 10: close-acct binds, releases ---")
|> app/ledger:last-minted(): h
|> std/fmt:ln("close-acct(handle: \"{{ h:s }}\")"): src
|> report(br, source: src.text, tag: "close")

[with]std/bridge:create(id: "probe-ledger", scope: "ledger"): br
|> vocab(br) |> open(br) |> post-ok(br) |> post-bad(br) |> worth-ok(br)
|> worth-miss(br) |> forged(br) |> denied(br) |> growth(br) |> close(br)
|> std/io:print.ln("--- done ---")
