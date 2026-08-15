// kopium increment B — the reply streams into a live vaxis pane.
//
// Increment A proved the critical path headless; this swaps `await` for
// `poll` under a `! tick` pump — the downloads.k topology, carrying a
// language model instead of progress bars. The reply accumulates in a
// store-held std/string instance; `! draw` renders it every frame; `q`
// quits mid-stream and the batch store's `! discharge` arm cancels the
// transfer. One thread, no callbacks, no executor.
//
// The SSE handling (koru/sse:feed, the yyjson delta ladder) is shared with
// increment A unchanged — which was the design bet A made: the tor does
// not change shape when the pump changes.
//
//   koruc run c_chat_pane.k
//
// Expected: chrome appears instantly, the sentence types
// itself into the body as deltas arrive.
//
// FINDINGS this increment pinned upstream (compiler bugs #6-#8 of the
// day, all instances of koru's frag-two-lowerings-share-one-contract):
//   - optional-param injection now lives in FOUR emission homes (400_180
//     covered two, 400_182 the other two), and raw-call sites pass the
//     empty Handlers type for effect-carrying targets.
//   - named store fields don't carry obligations through the `| full`
//     rejection record (f.s untracked) — the anonymous single-field form
//     (downloads' idiom) is what this file speaks. FLOATED, not yet pinned.
//   - a tor's own params don't thread into sweep-arm captures (branch
//     bindings do — downloads' pr.index) — hence the append lives inline
//     in the ladder rather than in an absorb tor. FLOATED, not yet pinned.
//   - `{{ }}` inside a child-tag attribute doesn't lift a component
//     param — the hint is baked static. FLOATED, not yet pinned.

import std/io
import std/string
import std/store
import std/fmt
import koru/vaxis
import koru/curl
import koru/yyjson
import koru/sse
import app/auth

std/store:new(ui) { live: 1[i64] }
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }

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
        <statusbar dock="bottom" h="1" hint="q quit"/>
    </dock>
}

// Identical ladder to increment A, with a transcript append where A
// printed. The append lives INLINE in the ok arm: `t` is a branch binding
// there, and branch bindings thread into sweep-arm captures (downloads'
// pr.index precedent) where a tor parameter would not (floated finding).
// No explicit close on that arm — append is the last use of the doc's
// arena, and auto-discharge places the close.
tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> std/store:query(reply)
                        ! query buf |> std/string:append(s: buf, text: t)
                            | ok |> _
                            | err _ |> _
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err _ |> _

// One frame's worth of transfer — poll BORROWS the promise out of the
// store, chunks drain through the same framing as increment A.
tor pump {}
pump = std/store:query(batch)
! query p |> koru/curl:poll(p)
    ! chunk ch |> std/store:query(framer)
        ! query fs |> koru/sse:feed(s: fs, bytes: ch.data)
            ! data d |> handle-delta(payload: d)
            | ok |> _
    ! finished r |> std/store:stored { ui.live: 0 } |> koru/curl:close(resp: r)
    | running |> _
    | complete |> _

tor start-stream { auth: string }
start-stream = koru/sse:new(): s |> std/store:insert(framer) { s }
| row _ |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: "{\"model\":\"anthropic/claude-haiku-4.5\",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"In two or three cheerful sentences, introduce yourself as kopium, a koru rebirth of the pi coding agent, streaming live inside its own terminal UI for the first time.\"}]}", headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
    | started p |> std/store:insert(batch) { p }
        | row _ |> _
        | full f |> koru/curl:cancel(p: f): m |> koru/curl:multi.close(m)
    | failed _ |> std/store:stored { ui.live: 0 }
| full f |> koru/sse:close(s: f)

// Seed the empty transcript row.
std/string:from-page(text: "")
| ok a |> std/string:take(s: a): text |> std/store:insert(reply) { text }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

// Key from pi's auth store (same flow as increment A), then launch.
std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/auth:bearer(key: k): auth |> koru/yyjson:close(doc) |> start-stream(auth)
                | wrong-type |> koru/yyjson:close(doc) |> std/store:stored { ui.live: 0 }
            | not-found |> koru/yyjson:close(doc) |> std/store:stored { ui.live: 0 }
        | not-found |> koru/yyjson:close(doc) |> std/store:stored { ui.live: 0 }
    | err _ |> std/store:stored { ui.live: 0 }
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")

koru/vaxis:run(title: "kopium")
| err e |> std/io:print.ln("kopium failed: {{ e:s }}")

koru/vaxis(kopium)
! draw w |> frame(win: w)
    |> koru/vaxis:sub-fill(parent: w, top: 1, bottom: 1): body
    |> std/store:query(reply)
    ! query buf |> std/string:read(s: buf): text |> koru/vaxis:write-in(win: body, x: 0, y: 0, text)
! tick _ when ui.live == 1 |> pump()
! key k when k.ch == 'q' |> koru/vaxis:quit()
