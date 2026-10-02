// PROBE, not a deliverable. The read loop, canned: a scripted `read`
// goes through `std/bridge:run` — the exact dispatch `session.k` turns and
// `live.k` drive use, not the bench gate's — and must show disk bytes the
// bridge could never see before, survive a missing file, keep the bridge
// alive, and join the derived vocabulary. A vulcan file-task attempt
// (py-expr-eval) rides along: its first step IS this read. No network, no
// model, no spend.
//
//   koruc probe_notes_read.k && ./a.out
import std/io
import std/bridge
import app/notes

[with]std/bridge:create(id: "probe-notes-read", scope: "notes"): br
|> std/io:print.ln("--- notes read, canned: the bridge opens what it could never see ---")
|> attempt(br)
|> missing(br)
|> survives(br)
|> show-vocabulary(br)
|> show-contrast(br)
|> std/io:print.ln("--- done ---")

// 1. THE VULCAN ATTEMPT: py-expr-eval's first step is opening the task file.
// The bridge has no eval verb, so the attempt honestly ends at reading —
// read opens, it does not run. The hidden-test closer is out of spend
// (no clone on disk, image pulls need approval); the verdict below is the
// run's own, quoted as given.
tor attempt { br: *std/bridge:Bridge }
attempt = std/io:print.ln("--- 1. attempt py-expr-eval: read the task file ---")
    |> std/bridge:run(br, source: "read(path: \"probe_task_expr.txt\")\n| ok text |> say(text: text)")
    | result r |> std/io:print.ln("read ran — bridge holds {{ r.handles:d }} resource(s), nothing minted")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG, ok was handled")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG, read should dispatch, not install")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, the file exists")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG, read is in this scope's register")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 2. A missing file hands back: the fragment handled only `| ok`, `missing`
// fired, and the bridge returned it as `unhandled-branch` (430_056) — the
// long-running bridge handing what nobody handled to the host. It does not
// refuse, it does not crash, and the session survives.
tor missing { br: *std/bridge:Bridge }
missing = std/io:print.ln("--- 2. missing file hands back, not a crash ---")
    |> std/bridge:run(br, source: "read(path: \"no-such-file.txt\")\n| ok |> say(text: \"found\")")
    | result r |> std/io:print.ln("result — WRONG, ok was handled but the file is missing (holds {{ r.handles:d }})")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — the hand-back, absence is not a refusal")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, absence is not a refusal")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 3. The bridge survives the miss: the old verbs still run after it.
tor survives { br: *std/bridge:Bridge }
survives = std/io:print.ln("--- 3. the session outlives the miss ---")
    |> std/bridge:run(br, source: "say(text: \"still here after not-found\")")
    | result r |> std/io:print.ln("say ran — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for say")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 4. The derived vocabulary includes the invention's sibling: read.
tor show-vocabulary { br: *std/bridge:Bridge }
show-vocabulary = std/io:print.ln("--- 4. derived vocabulary (register, now with read) ---")
    |> std/bridge:vocabulary(br)
    | ok v |> std/io:print.ln("{{ v:s }}")
    | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")

// 5. The wall did not move: what was never declared is still denied.
tor show-contrast { br: *std/bridge:Bridge }
show-contrast = std/io:print.ln("--- 5. contrast: delete was never declared ---")
    |> std/bridge:run(br, source: "delete(path: \"probe_task_expr.txt\")")
    | result r |> std/io:print.ln("result — WRONG, delete is not a verb (holds {{ r.handles:d }})")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for delete")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG, a declaration is not an invocation")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, nothing to refuse")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — the wall held, smallest wall kept")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

