// kopium with a head — type at the bottom, the agent acts on a live bridge.
//
// e_scrollback chrome (vaxis dock, VIEWPORT transcript with scrollback,
// edit line, curl multi + SSE under a tick) carrying live.k's agent loop
// (the notes vocabulary, a real model, a resource bridge that outlives
// every turn).
//
// STATE 2026-09-11 — VERIFIED live under a pty, real turns against
// deepseek-v4-flash: chained partial programs ran (`open | ok h |> append`,
// two steps, both completed); an unparseable reply came back as a tool
// result and the model recovered next turn; the transcript scrolls
// (^u/^d near-page, ^t/^b ends) while follow pins the tail. The turn-3
// hang reported below is FIXED — and it was never one bug:
//
//   1. deepseek-v4-flash is a REASONING model: it burns delta.reasoning
//      while content stays empty, so max_tokens 100 never reached the
//      utterance (empty reply → parse error). Budget is 2000 now, and a
//      dim italic strip between transcript and prompt renders the LIVE
//      reasoning delta — the thought frontier, cleared at turn end.
//   2. The SSE framer is ONE per process, minted at startup. The old
//      drop-then-remint called take(framer[0]) — a literal index, always
//      | empty — so two framers coexisted and pump swept BOTH; every
//      delta appended twice ("saysay", "open(pathopen(path:"). A
//      completed response leaves the buffer empty; reuse is correct.
//   3. `take(batch[0])` is a permanent no-op — a literal is never a row
//      handle (brand 0 is never minted; handles come from `| row rh`),
//      so retire never retired and turn 3's insert hit `| full` — the
//      original hang, in full. brow tracking (d_turns') is restored:
//      take the row insert reported. frag-store-take-by-index-orphans.
//   4. `!` arms are FIRST-MATCH — each emitted guard ends in `return`
//      (output_emitted.zig). The stall watchdog sits BEFORE the pump arm
//      or `ui.live == 1` swallows every tick. frag-event-arms-first-match.
//   5. A stream that goes silent ~60s (3750 ticks, no bytes) is cancelled
//      by its tracked row and the head stays alive — the 08-07 wedge is
//      survivable now.
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
//    A store column holding `*std/bridge:Bridge<session!>` is an
//    owned-resource column, which `690_055`'s own header still calls "currently
//    RED". It is green, and `probe_bridge_store.k` in this directory is the
//    twenty-line check that settled it.
//
// 2. `handle-delta` CONSUMES the extracted text inline rather than returning
//    it. That is the whole difference between this and `d_turns.k`, whose
//    replies come back as NUL bytes
//    (wired/holes/3_extracted_string_is_a_borrow_that_escapes). The hazard is
//    the escape, not the extraction.
//
// KNOWN, and visible while you use it: the transcript soft-wraps at the
// body width (koru/vaxis:scrollview reflows at win.width; rescroll counts
// the same reflow via wrap-lines at scroll.w), and the thinking strip
// shows only the latest reasoning chunk — the frontier, not the thought.
// Scroll granularity: arrows step one VISUAL row, pgup/pgdn a near-page,
// the wheel three rows — arrows ride kitty functional codepoints
// (57350..57355) which koru/vaxis passes with ch=0, and the wheel needs
// the `! mouse` arm below to exist or capture never turns on.

import std/env
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
std/store:new(ui) { live: 0[i64], retire: 0[i64], stall: 0[i64], brow: 0[i64] }

// The bridge itself. An owned-resource column; teardown closes it, and with it
// every note the agent still holds.
std/store:new(session, capacity: 2) { *std/bridge:Bridge<session!> }

// Scrollback state — e_scrollback.k's increment, ported: the transcript
// paints through the catalog viewport and the store owns the offset.
// h = term.height - 4 (topbar, statusbar, input, one pad — kept in step
// with the draw sub-fill by hand), refreshed by `! resize`. y/lines are
// denominated in VISUAL ROWS — draw and rescroll both run the transcript
// through koru/vaxis:wrap-lines at scroll.w first, so paint and count are
// the same bytes and a resize re-flows both.
std/store:new(scroll) { y: 0[i64], lines: 0[i64], h: 0[i64], w: 0[i64], follow: 1[i64], ty: 0[i64] }

// What you see.
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }
// What the model sees: escaped, comma-prefixed chat messages.
std/store:new(history, capacity: 2) { *std/string:String<instance!> }
// This turn's streamed reply, cleared before each send.
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }
// The live edge of the model's reasoning — delta.reasoning is a stream of
// its own that never reaches `reply`. We keep only the LATEST chunk (clear
// + append), so the strip shows the thought frontier without dragging a
// second transcript behind the pane.
std/store:new(thinking, capacity: 2) { *std/string:String<instance!> }
// The line you are typing.
std/store:new(draft, capacity: 2) { *std/string:String<instance!> }

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
        <statusbar dock="bottom" h="1" hint="enter send | esc quit | arrows/wheel scroll | ^u/^d page | ^t/^b ends"/>
    </dock>
}

// ── small writers ───────────────────────────────────────────────────────────
// Recount the transcript and hold the offset honest. `done n` is the piece
// count of a "\n" split — the widget's line count plus the trailing-empty
// skew e_scrollback.k names (transient one-line overshoot, self-heals on
// the next append). While `follow` holds, y rides the bottom edge; a
// scroll-up drops it until the pane reaches bottom again or a turn sends.
tor rescroll {}
rescroll = std/store:query(transcript)
! query buf |> std/fmt:ln("{{ buf:S }}"): t |> koru/vaxis:wrap-lines(content: t.text, width: scroll.w): wrapped |> std/string:split(s: wrapped, sep: "\n")
    ! piece _ |> _
    | done n when scroll.follow == 1 and @as(i64, @intCast(n)) > scroll.h |> std/store:stored { scroll.lines: @as(i64, @intCast(n)), scroll.y: @as(i64, @intCast(n)) - scroll.h }
    | done n when scroll.follow == 1 |> std/store:stored { scroll.lines: @as(i64, @intCast(n)), scroll.y: 0 }
    | done n when scroll.y > @as(i64, @intCast(n)) - 1 |> std/store:stored { scroll.lines: @as(i64, @intCast(n)), scroll.y: @as(i64, @intCast(n)) - 1 }
    | done n |> std/store:stored { scroll.lines: @as(i64, @intCast(n)) }

tor show { text: string }
show = std/store:query(transcript)
! query buf |> std/string:append(s: buf, text)
    | ok |> rescroll()
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

// One reasoning chunk in, frontier out: clear + append keeps the strip at
// the stream's edge. `think` is reached from handle-delta's `reasoning`
// arm — content:"" rides along in the same delta and appends nothing.
tor think { text: string }
think = std/fmt:ln("… {{ text:s }}"): mt |> std/store:query(thinking)
! query buf |> std/string:clear(s: buf) |> std/string:append(s: buf, mt.text)
    | ok |> _
    | err _ |> _

tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "reasoning")
                | found rv |> koru/yyjson:as.string(doc, v: rv)
                    | ok rt |> think(text: rt) |> std/io:free(content: rt)
                        |> koru/yyjson:object.get(doc, v: dv, key: "content")
                            | found tv |> koru/yyjson:as.string(doc, v: tv)
                                | ok t |> collect(text: t) |> std/io:free(content: t) |> koru/yyjson:close(doc)
                                | wrong-type |> koru/yyjson:close(doc)
                            | not-found |> koru/yyjson:close(doc)
                    | wrong-type |> koru/yyjson:object.get(doc, v: dv, key: "content")
                        | found tv |> koru/yyjson:as.string(doc, v: tv)
                            | ok t |> collect(text: t) |> std/io:free(content: t) |> koru/yyjson:close(doc)
                            | wrong-type |> koru/yyjson:close(doc)
                        | not-found |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:object.get(doc, v: dv, key: "content")
                    | found tv |> koru/yyjson:as.string(doc, v: tv)
                        | ok t |> collect(text: t) |> std/io:free(content: t) |> koru/yyjson:close(doc)
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
! query br |> app/wire:warm-grammar(br) |> std/bridge:run(br, source: src)
    | result r |> std/fmt:ln("[tool result] ok, it ran. The session now holds {{ r.handles:d }} open resource(s).\n\n"): ma
        |> announce(ma.text)
    | unhandled-branch _ |> std/io:print.ln("  UNHANDLED (discard)")
    | defined d |> std/fmt:ln("[tool result] defined: '{{ d:s }}' is now a verb in this session's vocabulary — callable on later turns.\n\n"): mi
        |> announce(mi.text)
    | dispatch-error e |> std/fmt:ln("[tool result] REFUSED: {{ e.message:s }}. '{{ e.event_name:s }}' did NOT run — you named a handle this session never issued.\n\n"): mb
        |> announce(mb.text)
    | event-denied ev |> std/fmt:ln("[tool result] DENIED: '{{ ev:s }}' is not in your vocabulary. Use only the verbs in Your vocabulary above — open, append, close, say, and every verb you defined this session.\n\n"): mc
        |> announce(mc.text)
    | parse-error p |> std/fmt:ln("[tool result] that was not Koru: {{ p.message:s }}. Each line is one invocation; a definition is two lines, the first starting with `tor `.\n\n"): md
        |> announce(md.text)
    | partial p |> std/fmt:ln("[tool result] your turn ran as {{ p.total:d }} step(s); {{ p.ran:d }} completed. Step report:\n{{ p.report:s }}open resources: {{ p.handles:d }}.\n\n"): mpp
        |> announce(mpp.text)
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
! query buf |> std/fmt:ln("{{ buf:S }}"): raw |> app/wire:clean(raw: raw.text)
    | ok cs |> std/fmt:ln("{{ cs:S }}"): src
        |> remember-said(role: "assistant", content: src.text)
        |> show(text: "\n")
        |> act(src: src.text)
        |> std/string:free(s: cs)
        |> unthink()
    | err _ |> unthink() |> show(text: "\n[could not snapshot the reply]\n\n")

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
    ! chunk ch |> std/store:stored { ui.stall: 0 } |> std/store:query(framer)
        ! query fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
            | ok |> _
    ! finished r |> std/store:stored { ui.live: 0, ui.retire: 1 } |> koru/curl:close(resp: r) |> dispatch()
    | running |> _
    | complete when ui.live == 1 |> std/store:stored { ui.live: 0, ui.retire: 1 }
        |> show(text: "\n[transfer ended without a finished event — reply may be partial]\n\n")
    | complete |> _

// ONE framer for the process lifetime — minted at startup, never swapped.
// The old drop-then-remint raced the store: the take lands a tick late, two
// rows coexisted, and pump's `! query fs` swept BOTH — every SSE event was
// appended twice ("saysay", "open(pathopen(path:"). A completed response
// leaves the framer's buffer empty, so reuse across turns is correct.
// Take the CURRENT row, never a guessed slot. fire() calls retire() in the
// same tick that send() inserts, and a store take lands a tick late — so
// the new row arrives at [1] while [0] is still being freed. take(batch[0])
// then hits empty forever and the live pending leaks: orphaned transfer,
// socket open, watchdog cancelling nothing. `brow` is d_turns' tracking,
// restored — the insert reports its own row.
tor retire {}
retire = std/store:take(batch[ui.brow])
| item p |> koru/curl:finish(p): m |> koru/curl:multi.close(m) |> std/store:stored { ui.retire: 0 }
| empty |> std/store:stored { ui.retire: 0 }

// Fire one turn. `req` is a tor parameter for the reason live.k records: a bare
// `body` puns from a param but not from a mid-chain bind.
tor send { req: string }
send = app/wire:recall(): auth |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> std/store:stored { ui.live: 1, ui.stall: 0 } |> std/store:insert(batch) { p }
    | row rh |> std/store:stored { ui.brow: rh }
    | full f |> koru/curl:cancel(p: f): m |> koru/curl:multi.close(m) |> std/store:stored { ui.live: 0 }
| failed _ |> std/store:stored { ui.live: 0 }

// Clear the in-flight reply and the thinking strip, then build this turn's
// request from the history.
tor ask { goal: string }
ask = std/store:query(reply)
! query buf |> std/string:clear(s: buf) |> std/store:query(thinking)
    ! query tb |> std/string:clear(s: tb)

// The turn ended — blank the strip so a stale frontier doesn't hang around.
tor unthink {}
unthink = std/store:query(thinking)
! query tb |> std/string:clear(s: tb)

tor fire { model: string, max_tokens: u32, temperature: string, goal: string }
fire = retire() |> std/store:query(history)
! query h |> std/fmt:ln("{{ h:S }}"): hist |> app/wire:agent-body(model, max_tokens, temperature, goal, history: hist.text): body |> send(req: body)

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

std/string:from-page(text: "")
| ok t0 |> std/string:take(s: t0): v0 |> std/store:insert(thinking) { v0 }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

koru/sse:new(): s |> std/store:insert(framer) { s }
| row _ |> _
| full f |> koru/sse:close(s: f)

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
                | ok k |> app/wire:bearer(key: k): auth |> std/io:free(content: k) |> app/wire:remember(auth) |> koru/yyjson:close(doc)
                | wrong-type |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | not-found |> koru/yyjson:close(doc)
    | err _ |> _
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")

koru/vaxis:run(title: "kopium")
| err e |> std/io:print.ln("kopium failed: {{ e:s }}")

// ── the loop ────────────────────────────────────────────────────────────────
// ! arms are FIRST-MATCH — each emitted guard block ends in `return` (see
// output_emitted.zig's tick handler). The stall watchdog must sit BEFORE
// the pump arm or `ui.live == 1` swallows every tick and it never runs.
koru/vaxis(kopium)
! draw w |> frame(win: w)
    |> koru/vaxis:sub-fill(parent: w, top: 1, bottom: 4): body
    |> koru/vaxis:sub-from-bottom(parent: w, up: 2, h: 1): iw
    |> std/store:query(draft)
    ! query d |> std/fmt:ln("> {{ d:S }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:query(transcript)
        ! query buf |> std/fmt:ln("{{ buf:S }}"): tline |> koru/vaxis:scrollview(win: body, content: tline.text, offset: scroll.y) |> std/store:query(thinking)
            ! query tk |> std/fmt:ln("{{ tk:S }}                                                                                                    "): thl
                |> koru/vaxis:style(bold: false, dim: true, italic: true, strikethrough: false): st
                |> koru/vaxis:write-styled(x: 0, y: @as(u16, @intCast(scroll.ty)), thl.text, style: st)
! tick _ when ui.live == 1 and ui.stall > 3750 |> show(text: "\n[stalled — no bytes for ~60s; cancelling] ") |> std/store:take(batch[ui.brow])
    | item p |> koru/curl:cancel(p): m |> koru/curl:multi.close(m)
        |> std/store:stored { ui.live: 0, ui.stall: 0 }
        |> unthink()
        |> show(text: "(cancelled the live transfer)\n\n")
    | empty |> std/store:stored { ui.live: 0, ui.stall: 0 } |> unthink() |> show(text: "(no batch row to cancel — flags cleared)\n\n")
! tick _ when ui.live == 1 |> pump() |> std/store:stored { ui.stall: ui.stall + 1 }
! tick _ when ui.retire == 1 |> retire()
! resize s |> std/store:stored { scroll.h: s.height - 5, scroll.ty: s.height - 4, scroll.w: s.width } |> rescroll()
! key k when k.ch == 27 |> koru/vaxis:quit()
! key k when (k.ch == 21 or (k.mods.ctrl and k.ch == 'u')) and scroll.y > scroll.h - 2 |> std/store:stored { scroll.y: scroll.y - (scroll.h - 2), scroll.follow: 0 }
! key k when (k.ch == 21 or (k.mods.ctrl and k.ch == 'u')) and scroll.y <= scroll.h - 2 |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! key k when (k.ch == 4 or (k.mods.ctrl and k.ch == 'd')) and scroll.y + scroll.h - 2 < scroll.lines - scroll.h |> std/store:stored { scroll.y: scroll.y + (scroll.h - 2) }
! key k when (k.ch == 4 or (k.mods.ctrl and k.ch == 'd')) and scroll.y + scroll.h - 2 >= scroll.lines - scroll.h and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when k.ch == 20 or (k.mods.ctrl and k.ch == 't') |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! key k when (k.ch == 2 or (k.mods.ctrl and k.ch == 'b')) and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when (k.ch == 2 or (k.mods.ctrl and k.ch == 'b')) and scroll.lines <= scroll.h |> std/store:stored { scroll.y: 0, scroll.follow: 1 }
! key k when k.codepoint == 57352 and scroll.y > 0 |> std/store:stored { scroll.y: scroll.y - 1, scroll.follow: 0 }
! key k when k.codepoint == 57353 and scroll.lines > scroll.h and scroll.y + 1 >= scroll.lines - scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when k.codepoint == 57353 and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.y + 1, scroll.follow: 0 }
! key k when k.codepoint == 57354 and scroll.y > scroll.h - 2 |> std/store:stored { scroll.y: scroll.y - (scroll.h - 2), scroll.follow: 0 }
! key k when k.codepoint == 57354 |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! key k when k.codepoint == 57355 and scroll.lines > scroll.h and scroll.y + scroll.h - 2 < scroll.lines - scroll.h |> std/store:stored { scroll.y: scroll.y + (scroll.h - 2), scroll.follow: 0 }
! key k when k.codepoint == 57355 and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! key k when k.codepoint == 57355 |> std/store:stored { scroll.follow: 1 }
! mouse m when m.kind == 0 and m.button == 64 and scroll.y > 2 |> std/store:stored { scroll.y: scroll.y - 3, scroll.follow: 0 }
! mouse m when m.kind == 0 and m.button == 64 |> std/store:stored { scroll.y: 0, scroll.follow: 0 }
! mouse m when m.kind == 0 and m.button == 65 and scroll.lines > scroll.h and scroll.y + 3 >= scroll.lines - scroll.h |> std/store:stored { scroll.y: scroll.lines - scroll.h, scroll.follow: 1 }
! mouse m when m.kind == 0 and m.button == 65 and scroll.lines > scroll.h |> std/store:stored { scroll.y: scroll.y + 3, scroll.follow: 0 }
! mouse m when m.kind == 0 and m.button == 65 |> std/store:stored { scroll.follow: 1 }
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:query(draft)
    ! query d |> std/fmt:ln("{{ d:S }}"): u |> std/store:stored { scroll.follow: 1 } |> show(text: "you: ")
        |> show(u.text)
        |> show(text: "\n\nagent: ")
        |> remember-said(role: "user", content: u.text)
        |> ask(goal: u.text)
        |> std/env:get.or(name: "KOPIUM_MODEL", default: "deepseek/deepseek-v4-flash-0731"): m
        |> fire(model: m, max_tokens: 2000, temperature: "1", goal: u.text)
        |> std/string:clear(s: d)
! key k when k.ch == 127 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 and k.mods.ctrl == false |> std/store:query(draft)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _

