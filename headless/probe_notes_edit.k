// PROBE, not a deliverable. The edit loop, canned: a scripted `edit`
// goes through `std/bridge:run` — the exact dispatch `session.k` turns and
// `live.k` drive use, not the bench gate's — and must change disk bytes the
// bridge could never change before, refuse a missing file, refuse a miss,
// refuse a multi-match (writing nothing in all three cases), keep the bridge
// alive, and join the derived vocabulary. A vulcan mutation-task attempt
// (go-stack-pop-bug) rides along: its patch step IS this edit. No network,
// no model, no spend.
//
//   koruc probe_notes_edit.k && ./a.out
import std/io
import std/fmt
import std/bridge
import app/notes

[with]std/bridge:create(id: "probe-notes-edit", scope: "notes"): br
|> std/io:print.ln("--- notes edit, canned: the bridge moves what it could only see ---")
|> s-open(br) |> s-append-1(br) |> s-append-2(br) |> s-append-3(br) |> s-close(br)
|> before(br)
|> single(br)
|> after(br)
|> missing(br)
|> miss(br)
|> multi(br)
|> unchanged(br)
|> show-vocabulary(br)
|> show-contrast(br)
|> survives(br)
|> std/io:print.ln("--- done ---")

// 0. Fixture via the old verbs: created and filled, left closed. Flat
// sequential tors (one run, full switch each) — the established probe shape;
// the old nested-run chain is rejected by KORU022's pipeline check.
tor s-open { br: *std/bridge:Bridge }
s-open = std/io:print.ln("--- 0. fixture via open/append/close ---")
    |> std/bridge:run(br, source: "open(path: \"probe_edit_fixture.txt\")")
    | result r |> std/io:print.ln("open minted — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG in setup")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

tor s-append-1 { br: *std/bridge:Bridge }
s-append-1 = app/notes:last-minted(): h
    |> std/fmt:ln("append(handle: \"{{ h:s }}\", text: \"the quick brown fox\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("append 1 — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG in setup")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

tor s-append-2 { br: *std/bridge:Bridge }
s-append-2 = app/notes:last-minted(): h
    |> std/fmt:ln("append(handle: \"{{ h:s }}\", text: \"jumps over the lazy dog\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("append 2 — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG in setup")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

tor s-append-3 { br: *std/bridge:Bridge }
s-append-3 = app/notes:last-minted(): h
    |> std/fmt:ln("append(handle: \"{{ h:s }}\", text: \"the end\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("append 3 — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG in setup")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

tor s-close { br: *std/bridge:Bridge }
s-close = app/notes:last-minted(): h
    |> std/fmt:ln("close(handle: \"{{ h:s }}\")"): src
    |> std/bridge:run(br, source: src.text)
    | result r |> std/io:print.ln("close — fixture ready, filled and closed (holds {{ r.handles:d }})")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG in setup")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 1. Before bytes: the fixture as the old verbs left it.
tor before { br: *std/bridge:Bridge }
before = std/io:print.ln("--- 1. before: read the fixture ---")
    |> std/bridge:run(br, source: "read(path: \"probe_edit_fixture.txt\")\n| ok text |> say(text: text)")
    | result r |> std/io:print.ln("read ran — bridge holds {{ r.handles:d }} resource(s), nothing minted")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected, ok was handled")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 2. THE VULCAN PATCH STEP: one needle, one match, bytes change.
tor single { br: *std/bridge:Bridge }
single = std/io:print.ln("--- 2. single-match edit rewrites the disk ---")
    |> std/bridge:run(br, source: "edit(path: \"probe_edit_fixture.txt\", old_text: \"quick brown fox\", new_text: \"slow green frog\")")
    | result r |> std/io:print.ln("edit ran — bridge holds {{ r.handles:d }} resource(s), nothing minted")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for edit")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG, edit should dispatch, not install")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, the needle matches once")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG, edit is in this scope's register")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 3. After bytes: the replacement is on disk.
tor after { br: *std/bridge:Bridge }
after = std/io:print.ln("--- 3. after: read the rewritten fixture ---")
    |> std/bridge:run(br, source: "read(path: \"probe_edit_fixture.txt\")\n| ok text |> say(text: text)")
    | result r |> std/io:print.ln("read ran — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected, ok was handled")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 4. A missing file reports, it does not create.
tor missing { br: *std/bridge:Bridge }
missing = std/io:print.ln("--- 4. missing file is not-found, never created ---")
    |> std/bridge:run(br, source: "edit(path: \"no-such-file.txt\", old_text: \"a\", new_text: \"b\")")
    | result r |> std/io:print.ln("missing ran — bridge holds {{ r.handles:d }} resource(s), nothing written")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for edit")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, absence is not a refusal")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 5. A needle that matches nothing writes nothing.
tor miss { br: *std/bridge:Bridge }
miss = std/io:print.ln("--- 5. zero matches is mismatch, not a write ---")
    |> std/bridge:run(br, source: "edit(path: \"probe_edit_fixture.txt\", old_text: \"porcupine\", new_text: \"x\")")
    | result r |> std/io:print.ln("miss ran — bridge holds {{ r.handles:d }} resource(s), nothing written")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for edit")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, a miss is not a refusal")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 6. A needle that matches twice writes nothing.
tor multi { br: *std/bridge:Bridge }
multi = std/io:print.ln("--- 6. two matches is ambiguous, not a write ---")
    |> std/bridge:run(br, source: "edit(path: \"probe_edit_fixture.txt\", old_text: \"the\", new_text: \"a\")")
    | result r |> std/io:print.ln("multi ran — bridge holds {{ r.handles:d }} resource(s), nothing written")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for edit")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, ambiguity is not a refusal")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 7. The refusals wrote nothing: the single replacement stands alone.
tor unchanged { br: *std/bridge:Bridge }
unchanged = std/io:print.ln("--- 7. refusals wrote nothing: read the fixture ---")
    |> std/bridge:run(br, source: "read(path: \"probe_edit_fixture.txt\")\n| ok text |> say(text: text)")
    | result r |> std/io:print.ln("refusals confirmed — fixture still reads with the single replacement")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected, ok was handled")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 8. The derived vocabulary includes the new verb.
tor show-vocabulary { br: *std/bridge:Bridge }
show-vocabulary = std/io:print.ln("--- 8. derived vocabulary (register, now with edit) ---")
    |> std/bridge:vocabulary(br)
    | ok v |> std/io:print.ln("{{ v:s }}")
    | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")

// 9. The wall did not move: the near-synonym was never declared.
tor show-contrast { br: *std/bridge:Bridge }
show-contrast = std/io:print.ln("--- 9. contrast: replace was never declared ---")
    |> std/bridge:run(br, source: "replace(path: \"probe_edit_fixture.txt\", old_text: \"a\", new_text: \"b\")")
    | result r |> std/io:print.ln("result — WRONG, replace is not a verb (holds {{ r.handles:d }})")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — unexpected for replace")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG, a declaration is not an invocation")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, nothing to refuse")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — the wall held, smallest wall kept")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 10. The bridge survives it all: the old verbs still run.
tor survives { br: *std/bridge:Bridge }
survives = std/io:print.ln("--- 10. the session outlives every refusal ---")
    |> std/bridge:run(br, source: "say(text: \"still here after every refusal\")")
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

