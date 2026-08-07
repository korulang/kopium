// kopium-headless, WIRED — the same agent, with a real model deciding.
//
// `session.k` is this program with the model canned, so the thing under test
// is the bridge. This is the other half: the invocations are not written down
// anywhere. A live claude-haiku-4.5 is handed the `notes` vocabulary and a
// goal, and whatever it emits goes straight to `std/bridge:run`.
//
// Nothing validates the model's reply before it runs. That is the point of
// the whole exercise — the refusal is the tool surface's job, not a
// pre-flight checker's, so an invocation that names a handle nobody issued
// has to die at dispatch and not before.
//
// Turn 3 is deliberately impossible: nothing has issued note_7, and asking
// the model to close it is asking for the confident wrong answer that is the
// single most likely thing an LLM emits.
//
//   koruc live.k && ./a.out
//
// Requires ~/.pi/agent/auth.json with an openrouter key — the same store
// `kopium/a_sse_spike.k` reads.

import std/io
import std/bridge
import app/notes
import app/wire
import koru/sse
import koru/curl
import koru/yyjson

// One SSE data payload -> its delta text, appended to the reply buffer.
//
// The append happens HERE, inside the arm that still owns `doc`. That is the
// whole difference between this and `d_turns.k`'s point-free version, which
// RETURNS the extracted text and hands back freed memory
// (kopium/holes/3_extracted_string_is_a_borrow_that_escapes). The hazard is
// the escape, so this one simply does not escape.
tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> app/wire:collect(text: t) |> koru/yyjson:close(doc)
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err _ |> _

// The streaming POST. Blocking (`await`), because this is headless — the same
// tor under a vaxis tick swaps `await` for `poll` and does not change shape.
//
// `body` is a tor PARAMETER rather than a mid-chain binding, and that is not
// style: punning a binding into `multi.add.post` further down the same chain
// comes back KORU080 "requires input 'body'". `d_turns.k:155` split at exactly
// this seam and its comment blames 690_234 — same seam, same reason.
tor send { req: string }
send = app/wire:recall(): auth |> koru/sse:new(): s |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> handle-delta(payload: d)
        | ok |> _
    ! finished r |> koru/curl:close(resp: r)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> std/io:print.ln("  transport failed: {{ e.msg:s }}") |> koru/sse:close(s)

// Build this turn's request and fire it.
tor ask { goal: string }
ask = app/wire:agent-body(goal): body |> send(req: body)

// One turn: state the goal, let the model answer, run what it said.
// `br` carries no phantom — a turn USES the session, it does not end it.
tor turn { br: *std/bridge:Bridge, n: u32, goal: string }
turn = app/wire:reset()
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  goal: {{ goal:s }}")
    |> ask(goal)
    |> app/wire:reply(): src
    |> std/io:print.ln("  model> {{ src:s }}")
    |> app/wire:remember-turn(goal, said: src)
    |> std/bridge:run(br, source: src)
        | result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
        | dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
        | event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
        | parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
        | exhausted _ |> std/io:print.ln("  budget exhausted")
        | validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
        | shape-error sh |> std/io:print.ln("  wrong shape: {{ sh.message:s }}")
        | scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")

// The session. Same four demonstrations as session.k, with nobody scripting
// the invocations.
tor converse {}
converse = std/bridge:create(id: "kopium-live", scope: "notes"): br
|> std/io:print.ln("--- session open, the agent's only tool is a Koru interpreter")
|> turn(br, n: 1, goal: "Open a note called agent-notes.txt.")
|> turn(br, n: 2, goal: "Write the line 'a live model wrote this' into the note you just opened.")
|> turn(br, n: 3, goal: "Close the note note_7.")
|> std/io:print.ln("--- transcript ends; no hang-up is written below this line")

// Startup: the bearer, then the conversation.
std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/wire:bearer(key: k): auth |> app/wire:remember(auth) |> koru/yyjson:close(doc) |> converse()
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
