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
// HONEST RED — the replies come back BLANK. See
// holes/3_extracted_string_is_a_borrow_that_escapes.
//
// The turn machinery is sound: typing echoes, Enter sends, status 200
// arrives, the `| ok` arm fires on every delta. But `handle-delta` now
// RETURNS the extracted text instead of appending it inline, and the
// `string` that `koru/yyjson:as.string` hands back is a BORROW into the
// document's arena. Auto-discharge closes that arena when the tor exits,
// so the transcript appends freed memory — five NUL bytes where "HELLO"
// should be, length intact, exit 0, no diagnostic anywhere.
//
// Not routed around, and deliberately not fixed here: this is the same
// hole 610_007 is parked RED on, whose own text says the borrow surface is
// Lars's ruling to make and must not be answered by invention. What this
// app adds is severity — 610_007's witness SIGSEGVs, which a harness
// catches; this one returns plausible data of the right length and exits
// clean. Increments A and B still work, and they differ in exactly one
// respect: they consume the text inside the arm that owns the doc. The
// hazard is the escape, not the extraction.

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

// The delta ladder, POINT-FREE. Increment B wrote this five levels deep with
// `| not-found |> close(doc)` three times, byte for byte — the `analysis`
// pyramid from the compiler, in an app. It collapses now: each stage leaves
// exactly one branch unclaimed, so the thread runs the whole ladder and the
// three chokes sit at the dedent, one per way the JSON can disappoint us.
//
// `doc` rides every stage explicitly — it's a value the thread can't carry, so
// no stage goes bare. The collapse is per-stage, which is the point.
//
// What the branch names bought: this ladder is HETEROGENEOUS (`not-found` from
// an object lookup, `out-of-range` from an index, `wrong-type` from a cast),
// and until koru 807107f9 a choke replicated onto every stage whether it
// declared the branch or not — so this exact shape was the one the feature
// couldn't reach. Found by reading these three duplicate lines and asking why.
// See holes/2_pointfree_choke_replicates_dead_claims.
//
// Extraction only: handle-delta now hands the text back and `pump` decides
// what to do with it. The transcript append moved to the caller.
tor handle-delta { payload: string }
| ok string
| gone
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "choices")
    |> koru/yyjson:array.get(doc, index: 0)
    |> koru/yyjson:object.get(doc, key: "delta")
    |> koru/yyjson:object.get(doc, key: "content")
    |> koru/yyjson:as.string(doc)
    | not-found |> koru/yyjson:close(doc) => gone
    | out-of-range |> koru/yyjson:close(doc) => gone
    | wrong-type |> koru/yyjson:close(doc) => gone
| err _ => gone

// One frame's worth of transfer. `| complete` only raises the retire
// flag — the batch row is taken out on the NEXT tick, never from inside
// its own sweep.
tor pump {}
pump = std/store:query(batch)
! query p |> koru/curl:poll(p)
    ! chunk ch |> std/store:query(framer)
        ! query fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
                | ok t |> std/store:query(transcript)
                    ! query buf |> std/string:append(s: buf, text: t)
                        | ok |> _
                        | err _ |> _
                | gone |> _
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
    |> std/store:query(draft)
    ! query d |> std/string:read(s: d): dtext |> std/fmt:ln("> {{ dtext:s }}_"): line |> koru/vaxis:write-in(win: iw, x: 0, y: 0, line.text) |> std/store:query(transcript)
        ! query buf |> std/string:read(s: buf): ttext |> koru/vaxis:write-in(win: body, x: 0, y: 0, text: ttext)
! tick _ when ui.live == 1 |> pump()
! tick _ when ui.retire == 1 |> retire()
! key k when k.ch == 27 |> koru/vaxis:quit()
! key k when k.ch == 13 and ui.live == 0 and ui.retire == 0 |> std/store:query(draft)
    ! query d |> std/string:read(s: d): utext |> app/auth:chat-body(prompt: utext): body |> std/store:query(transcript)
        ! query buf |> std/string:append(s: buf, text: "you: ")
            | ok |> std/string:append(s: buf, text: utext)
                | ok |> std/string:append(s: buf, text: "\n\nclaude: ")
                    | ok |> std/string:clear(s: d) |> send(body)
                    | err _ |> _
                | err _ |> _
            | err _ |> _
! key k when k.ch == 127 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch == 8 |> std/store:query(draft)
    ! query d |> std/string:pop-char(s: d)
! key k when k.ch >= 32 and k.ch < 127 and ui.live == 0 |> std/store:query(draft)
    ! query d |> std/string:append-char(s: d, k.ch)
        | ok |> _
        | err _ |> _
