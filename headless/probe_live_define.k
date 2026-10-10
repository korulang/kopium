// PROBE, not a deliverable. The live path's define loop, canned: a scripted
// two-line declaration goes through `app/wire:clean` — the exact intake
// `live.k` drive uses, not the bench gate's — and must arrive whole,
// install, redispatch, and join the derived renders. No network, no model,
// no spend.
//
//   koruc probe_live_define.k && ./a.out
import std/io
import std/fmt
import std/string
import std/bridge
import app/notes
import app/wire

[with]std/bridge:create(id: "probe-live-define", scope: "notes"): br
|> std/io:print.ln("--- live define, canned: scripted reply through wire:clean + bridge:run ---")
|> show-prompt(br)
|> define(br)
|> redispatch(br)
|> show-renders(br)
|> show-contrast()
|> std/io:print.ln("--- done ---")

// 1. Discoverability: the prompt names the two-line define shape.
tor show-prompt { br: *std/bridge:Bridge<session> }
show-prompt = app/wire:warm-grammar(br)
    |> app/wire:agent-body(model: "canned", max_tokens: 100, temperature: "0", goal: "teach the session a new verb", history: ""): body
    |> std/io:print.ln("--- 1. prompt (what the model is shown) ---")
    |> std/io:print.ln("{{ body:s }}")

// 2 + 3. Arrival + install: clean keeps both lines, run reports defined.
// Split like live.k's drive/act: `define` owns the snapshot String and frees
// it on one visible line after the last use.
tor define { br: *std/bridge:Bridge<session> }
define = app/wire:clean(raw: "tor greet { msg: string }\ngreet = say(text: msg)")
| ok cs |> std/fmt:ln("{{ cs:S }}"): src
    |> std/io:print.ln("--- 2. live intake keeps the declaration whole ---")
    |> std/io:print.ln("cleaned> {{ src.text:s }}")
    |> install(br, source: src.text)
    |> std/string:free(s: cs)
| err e |> std/io:print.ln("clean failed: {{ e:s }}")

tor install { br: *std/bridge:Bridge<session>, source: string }
install = std/io:print.ln("--- 3. run on the cleaned source ---")
    |> std/bridge:run(br, source)
    | result r |> std/io:print.ln("result — WRONG, the declaration dispatched as an invocation (holds {{ r.handles:d }})")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG, the declaration should install")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — installed into this session")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, nothing to refuse")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG, a declaration is not a verb")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG, the declaration never arrived")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 4. Growth closes: the invention dispatches next turn.
tor redispatch { br: *std/bridge:Bridge<session> }
redispatch = std/io:print.ln("--- 4. next turn calls the invention ---")
    |> std/bridge:run(br, source: "greet(msg: \"hello from a defined flow\")")
    | result r |> std/io:print.ln("greet ran — bridge holds {{ r.handles:d }} resource(s)")
    | unhandled-branch ub |> std/io:print.ln("  UNHANDLED branch=[{{ ub.branch:s }}] — WRONG, greet should dispatch")
    | defined d |> std/io:print.ln("DEFINED {{ d:s }} — WRONG, greet should dispatch, not install")
    | dispatch-error e |> std/io:print.ln("REFUSED: {{ e.message:s }} — WRONG, greet is installed")
    | event-denied ev |> std/io:print.ln("DENIED {{ ev:s }} — WRONG, greet is in this session's vocabulary")
    | residue r |> std/io:print.ln("residue: {{ r.report:s }}")
    | parse-error p |> std/io:print.ln("parse-error: {{ p.message:s }} — WRONG")
    | exhausted _ |> std/io:print.ln("exhausted — WRONG")
    | validation-error v |> std/io:print.ln("invalid: {{ v:s }} — WRONG")
    | shape-error sh |> std/io:print.ln("shape-error: {{ sh.message:s }} — WRONG")
    | scope-not-found s2 |> std/io:print.ln("no such scope: {{ s2:s }} — WRONG")

// 5 + 6. The derived renders include the invention.
tor show-renders { br: *std/bridge:Bridge<session> }
show-renders = std/io:print.ln("--- 5. derived vocabulary (register + inventions) ---")
    |> std/bridge:vocabulary(br)
    | ok v |> std/io:print.ln("{{ v:s }}")
        |> std/io:print.ln("--- 6. derived grammar (rules + inventions) ---")
        |> std/bridge:grammar(br)
        | ok g |> std/io:print.ln("{{ g:s }}")
        | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")
    | not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")

// 7. The flip: a two-invocation reply is no longer truncated to its head.
tor show-contrast {}
show-contrast = std/io:print.ln("--- 7. contrast: clean keeps the whole turn, both invocations ---")
    |> app/wire:clean(raw: "open(path: \"a\")\nclose(handle: \"deadbe\")")
    | ok first |> std/fmt:ln("{{ first:S }}"): whole
        |> std/io:print.ln("kept: [{{ whole.text:s }}]")
        |> std/string:free(s: first)
    | err e |> std/io:print.ln("clean failed: {{ e:s }}")
