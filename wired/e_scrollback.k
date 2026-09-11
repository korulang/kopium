// kopium increment E — SCROLLBACK. Increment D's clipped write-in becomes
// the catalog viewport: the transcript is one host-owned string, the store
// owns the offset, the widget paints only the visible slice.
//
// What changed, concretely:
//   - `scroll` store: y (offset), lines (transcript line count), h (pane
//     height), follow (pin-to-bottom flag).
//   - The transcript paints through `koru/vaxis:viewport(win: body, …)`,
//     not `write-in` — hard-clip is the widget's honest no-soft-wrap.
//   - `! resize` carries SizeData on mount + every real resize, so the host
//     DOES know the pane height: h = term.height - 4 (topbar 1, statusbar
//     1, input 1, one pad — kept in step with the `sub-fill(top:1,bottom:3)`
//     below by hand). The viewport file's "host cannot see the window
//     height" float is answered app-side: the event was already there.
//   - `rescroll` recounts lines after every transcript append and, while
//     `follow` holds, pins y = lines - h. Scrolling up drops follow;
//     arriving back at the bottom (or sending) re-arms it.
//   - Scroll keys are CONTROL chords — j/k/g/G/d/u are all typeable draft
//     text now, and arrows never reach `! key` (the 0x3000 wall). Both
//     spellings are armed: legacy terminals deliver ^u/^d/^t/^b as
//     codepoints 21/4/20/2; kitty-protocol terminals deliver the letter
//     with mods.ctrl. `== false` on the typing arm keeps chords out of the
//     draft.
//   - ESC quits. D's header claimed this and no arm implemented it — E
//     adds `k.ch == 27` and makes the claim true.
//
// Scope cuts, named plainly:
//   - line count is recomputed by re-splitting the WHOLE transcript on
//     every append — O(transcript) per SSE chunk, naive-phase honest.
//   - `done n` counts pieces including a trailing newline's empty tail;
//     the widget trims first. When the transcript ends in "\n" mid-stream
//     the host overshoots by a line for one frame — transient, self-heals
//     on the next chunk. Trimming koru-side needs a char-level probe
//     std/string doesn't have yet.
//   - still single-turn context (the JSON builder is the named depth
//     pass); still no soft-wrap.
//
//   koruc run e_scrollback.k
//
// Expected: chrome + "> " prompt; typing echoes; Enter streams a reply
// that auto-follows at the bottom; ^u/^d scroll a near-page, ^t/^b jump
// to top/bottom; scrolling up mid-stream holds position while text grows;
// ESC quits.
//
// VERIFIED 2026-09-11 under a pty against a 60-line seeded transcript
// (probe variant, seed only differed): follow pinned the tail on mount,
// ^u/^d stepped a near-page both directions, ^t/^b jumped to the ends,
// typed text landed in the draft while scrolled (chords did not leak),
// ESC quit clean. This terminal delivered the legacy codepoints; the
// kitty mods.ctrl spelling is armed but unwitnessed here. One visible
// artifact, as named: the trailing-newline skew leaves a one-line
// overshoot at the bottom edge (a blank row) until the next append.

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
std/store:new(scroll) { y: 0[i64], lines: 0[i64], h: 0[i64], follow: 1[i64] }

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
        <statusbar dock="bottom" h="1" hint="enter send | esc quit | ^u/^d scroll | ^t/^b ends"/>
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
                                | ok |> rescroll()
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

// Recount the transcript and hold the offset honest. `done n` is the piece
// count of a "\n" split — the widget's line count plus the trailing-empty
// skew named in the header. While `follow` holds, y rides the bottom edge
// (lines - h, never below 0); once the user scrolls up it stays put and the
// pane stops chasing the stream. Called after every transcript append.
tor rescroll {}
rescroll = std/store:query(transcript)
! query buf |> std/fmt:ln("{{ buf:S }}"): t |> std/string:split(s: t.text, sep: "\n")
    ! piece _ |> _
    | done n when scroll.follow == 1 and @as(i64, @intCast(n)) > scroll.h |> std/store:stored { scroll.lines: @as(i64, @intCast(n)), scroll.y: @as(i64, @intCast(n)) - scroll.h }
    | done n when scroll.follow == 1 |> std/store:stored { scroll.lines: @as(i64, @intCast(n)), scroll.y: 0 }
    | done n |> std/store:stored { scroll.lines: @as(i64, @intCast(n)) }

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
            | ok |> std/store:stored { scroll.follow: 1 } |> rescroll() |> send(req)
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

// Scroll keys are CONTROL chords — printable keys belong to the draft and
// arrows never reach `! key` (the 0x3000 wall). Both spellings armed:
// legacy terminals deliver ^u/^d/^t/^b as codepoints 21/4/20/2; kitty
// terminals deliver the letter with mods.ctrl. One store behind them.
koru/vaxis(kopium)
! draw w |> frame(win: w)
    |> koru/vaxis:sub-fill(parent: w, top: 1, bottom: 3): body
    |> koru/vaxis:sub-from-bottom(parent: w, up: 2, h: 1): iw
    |> std/store:query(draft)
    ! query d |> std/fmt:ln("> {{ d:S }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:query(transcript)
        ! query buf |> std/fmt:ln("{{ buf:S }}"): tline |> koru/vaxis:viewport(win: body, content: tline.text, offset: scroll.y)
! tick _ when ui.live == 1 |> pump()
! tick _ when ui.retire == 1 |> retire()
! resize s |> std/store:stored { scroll.h: s.height - 4 } |> rescroll()
! key k when k.ch == 27 |> koru/vaxis:quit()
! key k when (k.ch == 21 or (k.mods.ctrl and k.ch == 'u')) and scroll.y > scroll.h - 2 |> std/store:stored { scroll.y: scroll.y - (scroll.h - 2), scroll.follow: 0 }
! key k when (k.ch == 21 or (k.mods.ctrl and k.ch == 'u')) and scroll.y <= scroll.h - 2 |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! key k when (k.ch == 4 or (k.mods.ctrl and k.ch == 'd')) and scroll.y + scroll.h - 2 < scroll.lines - scroll.h |> std/store:stored { scroll.y: scroll.y + (scroll.h - 2) }
! key k when (k.ch == 4 or (k.mods.ctrl and k.ch == 'd')) and scroll.y + scroll.h - 2 >= scroll.lines - scroll.h and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when k.ch == 20 or (k.mods.ctrl and k.ch == 't') |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! key k when (k.ch == 2 or (k.mods.ctrl and k.ch == 'b')) and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when (k.ch == 2 or (k.mods.ctrl and k.ch == 'b')) and scroll.lines <= scroll.h |> std/store:stored { scroll.y: 0, scroll.follow: 1 }
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:query(draft)
    ! query d |> std/fmt:ln("{{ d:S }}"): u
        |> app/auth:chat-body(prompt: u.text): body
        |> std/string:clear(s: d)
        |> commit(u.text, req: body)
! key k when k.ch == 127 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 and k.mods.ctrl == false |> std/store:query(draft)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
