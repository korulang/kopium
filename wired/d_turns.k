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
// The draft-line leak this file found is FIXED — koru 051c9470 taught
// `clear` and `pop-char` to free what they drop (pinned 610_023/024). All
// three exit paths now leave clean: one turn, two turns, and ESC mid-stream.
//
// GREEN 2026-09-05 — first on the workaround, now on the ruling.
// handle-delta went back to the explicit pyramid and copied the text into
// an owned String BEFORE `close`; then 610_007 LANDED (KORU095 bans the
// returned borrow, `as.string` copies out of the arena itself) and the whole
// ladder collapsed into consume-inline: extract, copy, append, close — one
// nest, void tor, auto-freed. Replies land. What changed is exactly one
// thing from the red shape: nothing extracted crosses a discharge — the
// borrow never leaves the arm that owns the doc, because a copy leaves
// instead.

import std/io
import std/string
import std/store
import std/fmt
import koru/vaxis
import koru/curl
import koru/yyjson
import koru/sse
import app/auth

std/store:new(ui) { live: 0[i64], retire: 0[i64], brow: 0[i64] }
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

// The delta ladder, EXPLICIT — deliberately not point-free. Going point-free
// is what exposed hole 3 (the return turned an inline consume into an
// escape). When 610_007 landed, `as.string` started copying out of the arena
// itself — so this ladder consumes the copy INLINE (append to the transcript
// right here) and returns NOTHING (void tor: nested `=>` re-raise of a unit
// branch miscompiles in the backend, and there is nothing to carry out).
// The debt is minted, used, and freed in one nest and never crosses a tor
// boundary. See holes/3_extracted_string_is_a_borrow_that_escapes.
tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "choices")
        | found ch |> koru/yyjson:array.get(doc, v: ch, index: 0)
            | found el |> koru/yyjson:object.get(doc, v: el, key: "delta")
                | found dl |> koru/yyjson:object.get(doc, v: dl, key: "content")
                    | found ct |> koru/yyjson:as.string(doc, v: ct)
                        | ok t |> koru/yyjson:close(doc) |> std/store:query(transcript)
                            ! query buf |> std/string:append(s: buf, text: t)
                                | ok |> _
                                | err _ |> _
                        | wrong-type |> koru/yyjson:close(doc)
                    | not-found |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | out-of-range |> koru/yyjson:close(doc)
        | not-found |> koru/yyjson:close(doc)
| err _ |> _
tor pump {}
pump = std/store:query(batch)
! query p |> koru/curl:poll(p)
    ! chunk ch |> std/store:query(framer)
        ! query fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
            | ok |> _
    ! finished r |> std/store:stored { ui.live: 0 } |> koru/curl:close(resp: r)
    | running |> _
    | complete |> std/store:stored { ui.retire: 1 }
// Retire the finished batch so the next turn starts clean.
tor retire {}
retire = std/store:take(batch[ui.brow])
| item p |> koru/curl:finish(p): m |> koru/curl:multi.close(m) |> std/store:stored { ui.retire: 0 }
| empty |> std/store:stored { ui.retire: 0 }

// Fire one turn. `req` rather than `body`: a bare `body` argument no longer
// puns into `multi.add.post` from this shape — the compiler reports KORU080
// against the `| started` continuation and auto-discharge then fails outright.
// `live.k` and `headed.k` already carry the same rename for the same reason.
// Auth comes from module state (a tor param in a SWEEP arm would be 690_234).
tor send { req: string }
send = app/auth:recall(): auth |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> std/store:stored { ui.live: 1 } |> std/store:insert(batch) { p }
    | row rh |> std/store:stored { ui.brow: rh }
    | full f |> koru/curl:cancel(p: f): m |> koru/curl:multi.close(m)
| failed _ |> std/store:stored { ui.live: 0 }

// Stamp the turn into the transcript and fire it.
//
// This exists because of 610_007 stage 2, and the Enter handler at the bottom
// of the file is the other half — the vaxis block admits no comments between
// its arms, so the explanation lives here.
//
// The handler used to `read` the store-held draft into `utext` and let that
// borrow travel: into `chat-body`, back out past a three-deep append ladder,
// and still live when `clear(s: d)` freed the bytes underneath it one line
// before `send`. It worked only because `chat-body` happens to copy into a
// fresh buffer (auth.kz:48-64) — swap it for a tor that returns a view and
// this is hole 3's blank pane again, silently, exit 0. And per 610_008 the
// `clear` is not even the only hazard: any append to the draft would have
// done it too, with the owner alive and no free anywhere.
//
// So the handler copies the draft with `fmt:ln` first (`read` retired under
// 610_007 — there is no borrow to travel anymore). `u.text` is a fresh
// allocated string nothing else can reach, and the copy buys back the
// ordering: `clear(s: d)` runs BEFORE the transcript is stamped, because
// the draft is no longer what the turn is reading from. Auto-discharge
// frees the copy after the chain.
tor commit { text: string, req: string }
commit = std/store:query(transcript)
! query buf |> std/string:append(s: buf, text: "you: ")
    | ok |> std/string:append(s: buf, text)
        | ok |> std/string:append(s: buf, text: "\n\nclaude: ")
            | ok |> send(req)
            | err _ |> _
        | err _ |> _
    | err _ |> _

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
    |> std/store:query(draft)
    ! query d |> std/fmt:ln("> {{ d:S }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:query(transcript)
        ! query buf |> std/fmt:ln("{{ buf:S }}"): tline |> koru/vaxis:write-in(win: body, x: 0, y: 0, tline.text)
! tick _ when ui.live == 1 |> pump()
! tick _ when ui.retire == 1 |> retire()
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:query(draft)
    ! query d |> std/fmt:ln("{{ d:S }}"): u
        |> app/auth:chat-body(prompt: u.text): body
        |> std/string:clear(s: d)
        |> commit(u.text, req: body)
! key k when k.ch == 127 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 |> std/store:query(draft)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
