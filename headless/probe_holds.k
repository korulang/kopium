// PROBE — the custody record: the resource world a successor can read.
//
// The world dir already persists VOCABULARY (heredity.k). This exercises the
// sibling organ: `holds.log` — every mint and release on a world-mounted
// bridge, witnessed at the event. Session A lives a clean life: mint,
// release, session-closed. Session B mounts the same world, mints a hold of
// its own, then READS the log back through its own `read` verb — the
// successor sees what A held and how it ended before it acts. (B's bridge
// is never closed by hand — the bridge itself is a `<session!>` obligation,
// so teardown closes it and the record completes anyway; only a kill leaves
// a span open.)
//
//   rm -rf holds-world && koruc probe_holds.k && ./a.out && cat holds-world/holds.log

import std/bridge
import std/io
import app/notes

tor holdrun { br: *std/bridge:Bridge<session>, source: string, tag: string }
holdrun = std/bridge:run(br, source)
| result r |> std/io:print.ln("[{{ tag:s }}] result")
| partial p |> std/io:print.ln("[{{ tag:s }}] partial {{ p.ran:d }}/{{ p.total:d }}")
| unhandled-branch ub |> std/io:print.ln("[{{ tag:s }}] unhandled {{ ub.branch:s }}")
| parse-error e |> std/io:print.ln("[{{ tag:s }}] parse-error {{ e.message:s }}")
| validation-error v |> std/io:print.ln("[{{ tag:s }}] validation-error {{ v:s }}")
| event-denied d |> std/io:print.ln("[{{ tag:s }}] event-denied {{ d:s }}")
| dispatch-error e |> std/io:print.ln("[{{ tag:s }}] dispatch-error {{ e.message:s }}")
| exhausted e |> std/io:print.ln("[{{ tag:s }}] exhausted")
| defined d |> std/io:print.ln("[{{ tag:s }}] defined {{ d:s }}")
| shape-error sh |> std/io:print.ln("[{{ tag:s }}] shape-error {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("[{{ tag:s }}] scope-not-found {{ s:s }}")
| residue r |> std/io:print.ln("[{{ tag:s }}] residue {{ r.report:s }}")

tor showlog { br: *std/bridge:Bridge<session> }
showlog = std/bridge:run(br, source: "read(path: \"holds-world/holds.log\")\n| ok t |> say(text: t)")
| result r |> std/io:print.ln("[readlog] the record, through read:")
| parse-error e |> std/io:print.ln("[readlog] parse-error {{ e.message:s }}")
| validation-error v |> std/io:print.ln("[readlog] validation-error {{ v:s }}")
| unhandled-branch ub |> std/io:print.ln("[readlog] unhandled {{ ub.branch:s }}")
| event-denied d |> std/io:print.ln("[readlog] event-denied {{ d:s }}")
| dispatch-error e |> std/io:print.ln("[readlog] dispatch-error {{ e.message:s }}")
| exhausted e |> std/io:print.ln("[readlog] exhausted")
| defined d |> std/io:print.ln("[readlog] defined {{ d:s }}")
| partial p |> std/io:print.ln("[readlog] partial")
| shape-error sh |> std/io:print.ln("[readlog] shape-error {{ sh.message:s }}")
| scope-not-found s |> std/io:print.ln("[readlog] scope-not-found {{ s:s }}")
| residue r |> std/io:print.ln("[readlog] residue {{ r.report:s }}")

// Session A: open → append → close the file, then close the bridge — a
// full life, fully recorded. Session B mounts the same world, mints a
// hold, reads the log through its own vocabulary, and then the program
// ends WITHOUT bridge:close — B's mint dies with the process.
[with]std/bridge:create(id: "sess-a", scope: "notes", world: "holds-world"): a
|> std/io:print.ln("--- session A: a clean life, open/append/close ---")
|> holdrun(br: a, source: "open(path: \"holds-scratch.txt\")\n| ok h |> append(handle: h, text: \"session A was here\")\n    | ok |> close(handle: h)", tag: "a")
|> std/bridge:close(br: a)
|> std/io:print.ln("--- session A closed cleanly")
|> std/bridge:create(id: "sess-b", scope: "notes", world: "holds-world"): b
|> std/io:print.ln("--- session B: mints a hold, reads the record ---")
|> holdrun(br: b, source: "open(path: \"holds-scratch.txt\")", tag: "b")
|> showlog(br: b)
|> std/io:print.ln("--- program ends; session B never closed by hand — teardown closes it and the record completes")
