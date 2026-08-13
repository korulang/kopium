// ⚠ HONEST STATE, 2026-08-07: TURNS 1 AND 2 WORK. TURN 3 DOES NOT.
//
// Turn 1 is clean end to end — the model opens a note, the bridge holds it, the
// tool result comes back into the conversation. Turn 2 reaches the resource
// turn 1 opened and writes to it. Turn 3 hangs: the transfer starts, no delta
// ever arrives, `! finished` never fires, so `ui.live` stays 1 and the keyboard
// goes dead with no message.
//
// WHAT IS RULED OUT, measured not assumed:
//   - Not the request. Turn 3's exact body replayed against OpenRouter with
//     fetch returns HTTP 200 and real deltas.
//   - Not the content. Reproduced with the third request varied.
//   - Not the agent logic. `live.k` runs the same loop for six turns on
//     `curl:await` and is stable.
//
// WHAT IS CONFIRMED: these capacity-2 "single slot" stores ACCUMULATE. The take
// happens a tick after the insert, so two rows coexist and `pump` sweeps both.
// Turn 2's reply arrives interleaved — `appen` + the whole string + `d(...)` —
// which is one chunk stream being framed twice. Two attempted fixes did not
// land: raising `ui.retire` from the `! finished` arm (the emitted Zig proves
// both flags are written), and dropping the spent framer before minting the new
// one. So the lifecycle is wronger than "one tick late" and I stopped rather
// than keep guessing.
//
// THE PART THAT IS NOT MINE: `kopium/d_turns.k` has this same pump/retire shape
// and its header records verification with TWO typed turns. If this is the
// pattern's bug rather than this file's, d_turns has it too and nobody has hit
// it. That is the first thing to check.
//
// `live.k` is the version to run today. This file is committed because the
// finding is worth more than the tidy tree.
//
// kopium with a head — type at the bottom, the agent acts on a live bridge.
//
// This is `kopium/d_turns.k`'s chrome (vaxis dock, transcript pane, edit line,
// curl multi + SSE under a tick) carrying `live.k`'s agent loop (the notes
// vocabulary, a real model, a resource bridge that outlives every turn).
//
// Type a request. Enter sends it. The model's reply streams into the pane and
// then RUNS against the bridge, and whatever the bridge says goes back into the
// conversation so the next thing you type is answered in context. ESC quits.
//
//   koruc headed.k && ./a.out
//
// Try, in order:
//   open a note called scratch.txt
//   write "hello from the tui" into it
//   close note_4          <- a handle nobody issued; watch it get refused
//   try again
//
// TWO THINGS THAT MADE THIS BUILDABLE TODAY AND WERE NOT OBVIOUS:
//
// 1. The bridge lives in a STORE. A vaxis arm is a handler, not a continuation
//    — it cannot see a flow binding — so the store is the only channel to it.
//    A store column holding `*std/bridge:Bridge<std/bridge:session!>` is an
//    owned-resource column, which `690_055`'s own header still calls "currently
//    RED". It is green, and `probe_bridge_store.k` in this directory is the
//    twenty-line check that settled it.
//
// 2. `handle-delta` CONSUMES the extracted text inline rather than returning
//    it. That is the whole difference between this and `d_turns.k`, whose
//    replies come back as NUL bytes
//    (kopium/holes/3_extracted_string_is_a_borrow_that_escapes). The hazard is
//    the escape, not the extraction.
//
// KNOWN, and visible while you use it: the transcript pane clips rather than
// wrapping or scrolling — the viewport widget is the next increment, exactly as
// d_turns.k said. Long replies run off the right edge.

import std/io
import std/fmt
import std/store
import std/string
import std/bridge
import app/notes
import app/wire
import koru/vaxis
import koru/curl
import koru/yyjson
import koru/sse

// ── session state ───────────────────────────────────────────────────────────
std/store:new(ui) { live: 0[i64], retire: 0[i64] }

// The bridge itself. An owned-resource column; teardown closes it, and with it
// every note the agent still holds.
std/store:new(session, capacity: 2) { *std/bridge:Bridge<std/bridge:session!> }

// What you see.
std/store:new(transcript, capacity: 2) { *std/string:String<std/string:instance!> }
// What the model sees: escaped, comma-prefixed chat messages.
std/store:new(history, capacity: 2) { *std/string:String<std/string:instance!> }
// This turn's streamed reply, cleared before each send.
std/store:new(reply, capacity: 2) { *std/string:String<std/string:instance!> }
// The line you are typing.
std/store:new(draft, capacity: 2) { *std/string:String<std/string:instance!> }

std/store:new(batch, capacity: 2) { *koru/curl:Pending<open!> }
! discharge p |> koru/curl:cancel(p) |> koru/curl:multi.close()

std/store:new(framer, capacity: 2) { *koru/sse:Stream<framing!> }

// ── chrome ──────────────────────────────────────────────────────────────────
koru/vaxis:component(topbar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(frame) {
    <dock>
        <topbar dock="top" h="1" title="== kopium — the agent's only tool is a Koru interpreter =="/>
        <statusbar dock="bottom" h="1" hint="enter send | esc quit"/>
    </dock>
}

// ── small writers ───────────────────────────────────────────────────────────
tor show { text: string }
show = std/store:query(transcript)
! query buf |> std/string:append(s: buf, text)
    | ok |> _
    | err _ |> _

tor remember-said { role: string, content: string }
remember-said = std/store:query(history)
! query h |> app/wire:msg(role, content): m |> std/string:append(s: h, text: m)
    | ok |> _
    | err _ |> _

tor seed-draft {}
seed-draft = std/string:from-page(text: "")
| ok a |> std/string:take(s: a): t |> std/store:insert(draft) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

// ── the delta ladder, inline-consuming ──────────────────────────────────────
tor collect { text: string }
collect = std/store:query(reply)
! query buf |> std/string:append(s: buf, text)
    | ok |> show(text)
    | err _ |> _

tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> collect(text: t) |> koru/yyjson:close(doc)
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err _ |> _

// ── the act: run what the model said, tell everyone what happened ───────────
//
// Parameterless on purpose. It is called from `pump`'s `! finished` arm, which
// is reached from a `! tick` handler, so everything it touches has to come out
// of a store. That constraint is what the bridge-in-a-store probe was for.
tor announce { text: string }
announce = show(text) |> remember-said(role: "user", content: text)

tor act { src: string }
act = std/store:query(session)
! query br |> std/bridge:run(br, source: src)
    | result r |> std/fmt:ln("[tool result] ok, it ran. The session now holds {{ r.handles:d }} open resource(s).\n\n"): ma
        |> announce(ma.text)
    | dispatch-error e |> std/fmt:ln("[tool result] REFUSED: {{ e.message:s }}. '{{ e.event_name:s }}' did NOT run — you named a handle this session never issued.\n\n"): mb
        |> announce(mb.text)
    | event-denied ev |> std/fmt:ln("[tool result] DENIED: '{{ ev:s }}' is not in your vocabulary. Use only open, append, close.\n\n"): mc
        |> announce(mc.text)
    | parse-error p |> std/fmt:ln("[tool result] that was not a Koru invocation: {{ p.message:s }}. Reply with exactly one invocation and no prose.\n\n"): md
        |> announce(md.text)
    | exhausted _ |> announce(text: "[tool result] budget exhausted; nothing ran.\n\n")
    | validation-error v |> std/fmt:ln("[tool result] invalid: {{ v:s }}\n\n"): mf
        |> announce(mf.text)
    | shape-error sh |> std/fmt:ln("[tool result] wrong shape: {{ sh.message:s }}\n\n"): mg
        |> announce(mg.text)
    | scope-not-found s2 |> std/fmt:ln("[tool result] no such scope: {{ s2:s }}\n\n"): mh
        |> announce(mh.text)

// The stream is done: take what the model said, record it, run it.
//
// THE COPY IS AT `clean` (610_007 stage 2). `raw` is a borrow of the
// store-held `reply` String, consumed on the next step — the safe shape. What
// used to travel was `clean`'s SUB-SLICE of it, through `remember-said`,
// `show` and `act`, and `act` runs whatever event the model chose. Nothing
// stopped one of those from appending to `reply` and reallocating the bytes
// `src` points at, owner alive, no free in sight (610_008). `clean` now hands
// back an owned String; `cs` is a local nothing downstream can reach and it
// dies on one visible line after the last use.
tor dispatch {}
dispatch = std/store:query(reply)
! query buf |> std/string:read(s: buf): raw |> app/wire:clean(raw)
    | ok cs |> std/string:read(s: cs): src
        |> remember-said(role: "assistant", content: src)
        |> show(text: "\n")
        |> act(src)
        |> std/string:free(s: cs)
    | err _ |> show(text: "\n[could not snapshot the reply]\n\n")

// ── transfer pump, one frame's worth ────────────────────────────────────────
//
// The `! finished` arm raises BOTH flags, and the second one is a bug fix
// rather than a belt. `d_turns.k` raises `retire` only from poll's
// `| complete` branch — but that same `! finished` arm sets `ui.live: 0`, and
// `! tick _ when ui.live == 1` is the only thing that calls `pump`, so once a
// transfer finishes pump never runs again and `| complete` is never observed.
// The row is then never taken out of `batch`, which has capacity 2: turns 1
// and 2 insert, turn 3 hits `| full`, its transfer is cancelled, and `ui.live`
// — set BEFORE the insert in `send` — stays 1 forever, so the keyboard goes
// dead with no message.
//
// Reproduced at turn 3 twice with the third request varied, to rule out the
// content. d_turns.k was verified with two typed turns and has the same shape.
tor pump {}
pump = std/store:query(batch)
! query p |> koru/curl:poll(p)
    ! chunk ch |> std/store:query(framer)
        ! query fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
            | ok |> _
    ! finished r |> std/store:stored { ui.live: 0, ui.retire: 1 } |> koru/curl:close(resp: r) |> dispatch()
    | running |> _
    | complete |> std/store:stored { ui.retire: 1 }

tor drop-framer {}
drop-framer = std/store:take(framer[0])
| item f |> koru/sse:close(s: f)
| empty |> _

tor retire {}
retire = drop-framer() |> std/store:take(batch[0])
| item p |> koru/curl:finish(p): m |> koru/curl:multi.close(m) |> std/store:stored { ui.retire: 0 }
| empty |> std/store:stored { ui.retire: 0 }

// Fire one turn. `req` is a tor parameter for the reason live.k records: a bare
// `body` puns from a param but not from a mid-chain bind.
tor send { req: string }
send = app/wire:recall(): auth |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> std/store:stored { ui.live: 1 } |> std/store:insert(batch) { p }
    | row _ |> _
    | full f |> koru/curl:cancel(p: f): m |> koru/curl:multi.close(m)
| failed _ |> std/store:stored { ui.live: 0 }

// Clear the in-flight reply, then build this turn's request from the history.
tor ask { goal: string }
ask = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

tor fresh-framer {}
fresh-framer = drop-framer() |> koru/sse:new(): s |> std/store:insert(framer) { s }
| row _ |> _
| full f |> koru/sse:close(s: f)

tor fire { goal: string }
fire = retire() |> fresh-framer() |> std/store:query(history)
! query h |> std/string:read(s: h): hist |> app/wire:agent-body(goal, history: hist): body |> send(req: body)

// ── startup ─────────────────────────────────────────────────────────────────
std/string:from-page(text: "kopium ready. tell the agent to open a note.\n\n")
| ok a |> std/string:take(s: a): t |> std/store:insert(transcript) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

std/string:from-page(text: "")
| ok b |> std/string:take(s: b): u |> std/store:insert(history) { u }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

std/string:from-page(text: "")
| ok c |> std/string:take(s: c): v |> std/store:insert(reply) { v }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

// A screen exists now, so the module stops writing to the terminal behind it.
app/notes:hush()

seed-draft()

std/bridge:create(id: "kopium-headed", scope: "notes"): br |> std/store:insert(session) { br }
| row _ |> _
| full f |> std/bridge:close(br: f)

std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/wire:bearer(key: k): auth |> app/wire:remember(auth) |> app/wire:warm-vocab() |> koru/yyjson:close(doc)
                | wrong-type |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | not-found |> koru/yyjson:close(doc)
    | err _ |> _
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")

koru/vaxis:run(title: "kopium")
| err e |> std/io:print.ln("kopium failed: {{ e:s }}")

// ── the loop ────────────────────────────────────────────────────────────────
koru/vaxis(kopium)
! draw w |> frame(win: w)
    |> koru/vaxis:sub-fill(parent: w, top: 1, bottom: 3): body
    |> koru/vaxis:sub-from-bottom(parent: w, up: 2, h: 1): iw
    |> std/store:query(draft)
    ! query d |> std/string:read(s: d): dtext |> std/fmt:ln("> {{ dtext:s }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:query(transcript)
        ! query buf |> std/string:read(s: buf): ttext |> koru/vaxis:write-in(win: body, x: 0, y: 0, text: ttext)
! tick _ when ui.live == 1 |> pump()
! tick _ when ui.retire == 1 |> retire()
! key k when k.ch == 27 |> koru/vaxis:quit()
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:query(draft)
    ! query d |> std/string:read(s: d): utext |> show(text: "you: ")
        |> show(text: utext)
        |> show(text: "\n\nagent: ")
        |> remember-said(role: "user", content: utext)
        |> ask(goal: utext)
        |> fire(goal: utext)
        |> std/string:clear(s: d)
! key k when k.ch == 127 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 |> std/store:query(draft)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
