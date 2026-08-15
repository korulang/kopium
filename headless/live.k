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
// THE SESSION IS TWO STORES. `transcript` is the conversation, `reply` is the
// turn in flight, and both are store-held Strings that grow. A bridge that
// holds resources across turns paired with a model that remembers nothing
// produces an agent that reopens what it already has — persistence has two
// halves, and these are the second one.
//
// Store capacity is fixed static memory, but that bounds ROWS, not bytes: an
// owned-String column grows without limit (690_053, 690_060). One row per
// MESSAGE is the shape a conversation actually wants — countable, replayable,
// compactable — and that is the one fixed capacity would bite. One growable
// String is what fits today, and it is a blob.
//
//   koruc live.k && ./a.out
//
// Requires ~/.pi/agent/auth.json with an openrouter key — the same store
// `kopium/a_sse_spike.k` reads.

import std/io
import std/fmt
import std/store
import std/string
import std/bridge
import app/notes
import app/wire
import koru/sse
import koru/curl
import koru/yyjson

// The conversation so far: escaped, comma-prefixed chat messages, spliced
// between the system message and the current goal.
std/store:new(transcript, capacity: 2) { *std/string:String<std/string:instance!> }

// This turn's streamed reply, cleared before each ask.
std/store:new(reply, capacity: 2) { *std/string:String<std/string:instance!> }

// One SSE delta -> the reply String. Called from inside the arm that still
// owns `doc`, which is the whole difference between this and `d_turns.k`'s
// point-free version — that one RETURNS the extracted text and hands back
// freed memory (kopium/holes/3_extracted_string_is_a_borrow_that_escapes).
// The hazard is the escape, so this simply does not escape.
tor collect { text: string }
collect = std/store:query(reply)
! query buf |> std/string:append(s: buf, text)
    | ok |> _
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

// The streaming POST. Blocking (`await`), because this is headless — the same
// tor under a vaxis tick swaps `await` for `poll` and does not change shape.
//
// `req` rather than `body`: a bare `body` argument puns from a tor PARAMETER
// but not from a mid-chain `: body` binding, and the failure is a KORU080
// claiming the input was never supplied. PARSE006 gives the precise rule.
tor send { req: string }
send = app/wire:recall(): auth |> koru/sse:new(): s |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> handle-delta(payload: d)
        | ok |> _
    ! finished r |> koru/curl:close(resp: r)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> std/io:print.ln("  transport failed: {{ e.msg:s }}") |> koru/sse:close(s)

// Build this turn's request from the transcript and fire it. `goal` is a tor
// parameter captured into a sweep arm — 690_234, green since 2026-08-03.
tor ask { goal: string }
ask = std/store:query(transcript)
! query h |> std/string:read(s: h): hist |> app/wire:agent-body(goal, history: hist): body |> send(req: body)

// Append this turn to the conversation, so the next one can reason from it.
tor record { goal: string, said: string }
record = std/store:query(transcript)
! query h |> app/wire:msg(role: "user", content: goal): m1 |> std/string:append(s: h, text: m1)
    | ok |> app/wire:msg(role: "assistant", content: said): m2 |> std/string:append(s: h, text: m2)
        | ok |> _
        | err _ |> _
    | err _ |> _

// What the bridge did, as a message the next turn will see.
//
// Role "user" rather than "tool": the OpenAI-shaped `tool` role needs a
// tool_call id, and this agent's tool call is a line of Koru rather than a
// function-call object. The `[tool result]` prefix is doing that work instead
// — honest about what it is, and the model reads it fine.
tor observe { text: string }
observe = std/store:query(transcript)
! query h |> app/wire:msg(role: "user", content: text): m |> std/string:append(s: h, text: m)
    | ok |> _
    | err _ |> _

// Run what the model said and TELL IT WHAT HAPPENED.
//
// Split out of `drive` for a lifetime reason, not a tidiness one: `drive` now
// owns a snapshot String it has to free on every path, and eight sibling
// branches would mean eight frees. With the branches behind a tor call the
// free is one line at the end of one chain.
//
// Every arm reports. A refusal the agent never hears about is a refusal it
// will repeat, and turn 4 exists to prove it hears.
tor act { br: *std/bridge:Bridge, goal: string, source: string }
act = record(goal, said: source) |> std/bridge:run(br, source)
| result r |> std/io:print.ln("  ok — bridge now holds {{ r.handles:d }} resource(s)")
    |> std/fmt:ln("[tool result] ok, it ran. The session now holds {{ r.handles:d }} open resource(s)."): ma
    |> observe(ma.text)
| dispatch-error e |> std/io:print.ln("  REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran")
    |> std/fmt:ln("[tool result] REFUSED: {{ e.message:s }}. '{{ e.event_name:s }}' did NOT run. HandleNotHeld means you named a handle this session never issued — check which handles you actually opened."): mb
    |> observe(mb.text)
| event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
    |> std/fmt:ln("[tool result] DENIED: '{{ ev:s }}' is not in your vocabulary. Use only open, append, close."): mc
    |> observe(mc.text)
| parse-error p |> std/io:print.ln("  the model did not emit Koru: {{ p.message:s }}")
    |> std/fmt:ln("[tool result] That was not a Koru invocation: {{ p.message:s }}. Reply with exactly one invocation and no prose."): md
    |> observe(md.text)
| exhausted _ |> std/io:print.ln("  budget exhausted")
    |> observe(text: "[tool result] budget exhausted; nothing ran.")
| validation-error v |> std/io:print.ln("  invalid: {{ v:s }}")
    |> std/fmt:ln("[tool result] invalid invocation: {{ v:s }}"): mf
    |> observe(mf.text)
| shape-error sh |> std/io:print.ln("  wrong shape: {{ sh.message:s }}")
    |> std/fmt:ln("[tool result] wrong shape: {{ sh.message:s }}"): mg
    |> observe(mg.text)
| scope-not-found s2 |> std/io:print.ln("  no such scope: {{ s2:s }}")
    |> std/fmt:ln("[tool result] no such scope: {{ s2:s }}"): mh
    |> observe(mh.text)

// Read what the model said, run it, and record the outcome. `br` is a tor
// parameter reaching `std/bridge:run` from inside a sweep arm — the shape
// probe_store.k pins.
//
// THE COPY IS AT `clean` (610_007 stage 2). `raw` is a borrow of the
// store-held `reply` String and it is consumed on the very next step, which is
// the safe shape. What used to travel was `clean`'s SUB-SLICE of that borrow —
// it went into `record`, into `std/bridge:run`, and out through eight arms,
// each of which can run arbitrary model-chosen `notes` events. Nothing stopped
// one of those from appending to `reply` and reallocating the bytes `src`
// points at, with the owner alive the whole time and no free anywhere
// (610_008). `clean` now returns an owned String: `cs` is a local nothing
// downstream can reach, and it dies on one visible line after the last use.
tor drive { br: *std/bridge:Bridge, goal: string }
drive = std/store:query(reply)
! query buf |> std/string:read(s: buf): raw |> std/io:print.ln("  raw  > [{{ raw:s }}]") |> app/wire:clean(raw)
    | ok cs |> std/string:read(s: cs): src
        |> std/io:print.ln("  model> {{ src:s }}")
        |> act(br, goal, source: src)
        |> std/string:free(s: cs)
    | err e |> std/io:print.ln("  could not snapshot the reply: {{ e:s }}")

// Clear the in-flight reply before the next ask.
tor clear-reply {}
clear-reply = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

// One turn. `br` carries no phantom — a turn USES the session, it does not
// end it.
tor turn { br: *std/bridge:Bridge, n: u32, goal: string }
turn = clear-reply()
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  goal: {{ goal:s }}")
    |> ask(goal)
    |> drive(br, goal)

// The session. Same four demonstrations as session.k, with nobody scripting
// the invocations.
tor converse {}
converse = std/bridge:create(id: "kopium-live", scope: "notes"): br
|> std/io:print.ln("--- session open, the agent's only tool is a Koru interpreter")
|> turn(br, n: 1, goal: "Open a note called agent-notes.txt.")
|> turn(br, n: 2, goal: "Write the line 'a live model wrote this' into the note you just opened.")
|> turn(br, n: 3, goal: "Close the note note_7.")
|> turn(br, n: 4, goal: "Try again.")
|> turn(br, n: 5, goal: "Open a note called scratch.txt. Leave it open.")
|> turn(br, n: 6, goal: "Now delete scratch.txt from disk entirely.")
|> std/io:print.ln("--- transcript ends; no hang-up is written below this line")

// Seed the two session Strings.
std/string:from-page(text: "")
| ok a |> std/string:take(s: a): t |> std/store:insert(transcript) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

std/string:from-page(text: "")
| ok b |> std/string:take(s: b): u |> std/store:insert(reply) { u }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err _ |> _

// Startup: the bearer, then the conversation.
std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/wire:bearer(key: k): auth |> app/wire:remember(auth) |> app/wire:warm-vocab() |> koru/yyjson:close(doc) |> converse()
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
