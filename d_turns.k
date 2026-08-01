// kopium increment D — TURNS. Type at the bottom, Enter sends, the reply
// streams into the transcript, repeat. ESC quits (q is typeable now).
//
// Increment B's pane grew a keyboard: the draft line is todo_tui's edit
// pattern (store-held String, append-char/pop-char), Enter reads the
// draft, JSON-escapes it into a request body (app/auth:chat-body), stamps
// "you:"/"claude:" into the transcript, reseeds an empty draft, and fires
// `send`. The batch retires through a second `! tick` arm (`retire`) so
// the next turn starts with a fresh multi — poll's `| complete` can't
// take its own swept row out from under itself.
//
// Scope cuts, named plainly:
//   - single-turn context: each send carries only the newest message.
//     Replaying history means SERIALIZING the transcript — yyjson is
//     read-v0, and the JSON builder is the named depth pass. When it
//     lands, chat-body grows a history parameter and this file becomes a
//     real conversation.
//   - no wrapping/scrollback in the transcript pane yet (write-in clips);
//     the viewport widget is the natural increment E.
//
//   koruc run d_turns.k
//
// Expected: chrome + "> " prompt appear; typing echoes into the prompt
// line; Enter streams a reply into the transcript; another turn works the
// same; ESC quits. VERIFIED live under a pty: two typed turns, replies
// streaming word-by-word at network chunk boundaries, ESC quitting from
// both mid-stream and post-stream.
//
// HONEST RED — `std/string:clear` leaks, so ESC exits 1:
//
//   KORU LEAK CHECK FAILED: the produced program leaked (1 outstanding)
//
// NOT this app's bug, and deliberately not routed around. A String's
// `data` slice IS its allocation record (koru_std/string.kz:12 — there is
// no capacity field), so `clear`'s `s.data.len = 0` orphans the buffer:
// the disposer's `allocator.free(s.data)` hits Allocator.free's
// zero-length early-return and frees nothing. Six-line repro, no TUI and
// no network — `from-page |> take |> clear |> free` leaks where the same
// chain without `clear` is clean. `clear` has zero regression coverage in
// the whole suite, which is how it shipped.
//
// The leak is exactly the draft line the turn was typed into (2 bytes for
// "hi"), and it is per-clear — i.e. per turn. Bisected: boot clean, typing
// clean, red the moment Enter runs.

import std/io
import std/string
import std/store
import std/fmt
import koru/vaxis
import koru/curl
import koru/yyjson
import koru/sse
import app/auth

std/store:new(ui) { live: 0[i64], retire: 0[i64] }
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }
std/store:new(draft, capacity: 2) { *std/string:String<instance!> }

std/store:new(batch, capacity: 2) { *koru/curl:Pending<open!> }
! discharge p |> koru/curl:cancel(p) |> koru/curl:multi.close()

std/store:new(framer, capacity: 2) { *koru/sse:Stream<framing!> }

koru/vaxis:component(topbar) {
    <text>{{ title:s }}</text>
}

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(frame) {
    <dock>
        <topbar dock="top" h="1" title="== kopium =="/>
        <statusbar dock="bottom" h="1" hint="enter send | esc quit"/>
    </dock>
}

// Fresh empty draft row — used at startup and after every send.
tor seed-draft {}
seed-draft = std/string:from-page(text: "")
| ok a |> std/string:take(s: a): t |> std/store:insert(draft) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

// Identical delta ladder to increment B.
tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> std/store:sweep(transcript)
                        ! sweep buf |> std/string:append(s: buf, text: t)
                            | ok |> _
                            | err _ |> _
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err _ |> _

// One frame's worth of transfer. `| complete` only raises the retire
// flag — the batch row is taken out on the NEXT tick, never from inside
// its own sweep.
tor pump {}
pump = std/store:sweep(batch)
! sweep p |> koru/curl:poll(p)
    ! chunk ch |> std/store:sweep(framer)
        ! sweep fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
            | ok |> _
    ! finished r |> std/store:stored { ui.live: 0 } |> koru/curl:close(resp: r)
    | running |> _
    | complete |> std/store:stored { ui.retire: 1 }

// Retire the finished batch so the next turn starts clean.
tor retire {}
retire = std/store:take(batch[0])
| item p |> koru/curl:finish(p): m |> koru/curl:multi.close(m) |> std/store:stored { ui.retire: 0 }
| empty |> std/store:stored { ui.retire: 0 }

// Fire one turn. `body` rides the head chain (a tor param in a SWEEP arm
// would be 690_234); auth comes from module state for the same reason.
tor send { body: string }
send = app/auth:recall(): auth |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> std/store:stored { ui.live: 1 } |> std/store:insert(batch) { p }
    | row _ |> _
    | full f |> koru/curl:cancel(p: f): m |> koru/curl:multi.close(m)
| failed _ |> std/store:stored { ui.live: 0 }

// Startup: transcript, framer, draft, bearer. No auto-send — the first
// turn is yours.
std/string:from-page(text: "kopium ready. say something.\n\n")
| ok a |> std/string:take(s: a): t |> std/store:insert(transcript) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

koru/sse:new(): s |> std/store:insert(framer) { s }
| row _ |> _
| full f |> koru/sse:close(s: f)

seed-draft()

std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/auth:bearer(key: k): auth |> app/auth:remember(auth) |> koru/yyjson:close(doc)
                | wrong-type |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | not-found |> koru/yyjson:close(doc)
    | err _ |> _
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")

koru/vaxis:run(title: "kopium")
| err e |> std/io:print.ln("kopium failed: {{ e:s }}")

koru/vaxis(kopium)
! draw w |> frame(win: w)
    |> koru/vaxis:sub-fill(parent: w, top: 1, bottom: 3): body
    |> koru/vaxis:sub-from-bottom(parent: w, up: 2, h: 1): iw
    |> std/store:sweep(draft)
    ! sweep d |> std/string:read(s: d): dtext |> std/fmt:ln("> {{ dtext:s }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:sweep(transcript)
        ! sweep buf |> std/string:read(s: buf): ttext |> koru/vaxis:write-in(win: body, x: 0, y: 0, text: ttext)
! tick _ when ui.live == 1 |> pump()
! tick _ when ui.retire == 1 |> retire()
! key k when k.ch == 27 |> koru/vaxis:quit()
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:sweep(draft)
    ! sweep d |> std/string:read(s: d): utext |> app/auth:chat-body(prompt: utext): body |> std/store:sweep(transcript)
        ! sweep buf |> std/string:append(s: buf, text: "you: ")
            | ok |> std/string:append(s: buf, text: utext)
                | ok |> std/string:append(s: buf, text: "\n\nclaude: ")
                    | ok |> std/string:clear(s: d) |> send(body)
                    | err _ |> _
                | err _ |> _
            | err _ |> _
! key k when k.ch == 127 |> std/store:sweep(draft)
    ! sweep d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:sweep(draft)
    ! sweep d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 |> std/store:sweep(draft)
    ! sweep d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
