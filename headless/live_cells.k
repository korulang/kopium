// kopium — a live model driving a CHILD CELL, not a top-level bridge.
//
// live_db.k's loop, re-pointed: the parent program owns a std/fleet on
// scope "db" + world "cells/", spawns child-1, and each turn borrows the
// cell and pumps a model reply into std/cell:run. The child's bridge —
// not this program's — holds custody across turns. Its world slice
// (cells/child-1/holds.log) is the parent's inspection surface; plain
// std/fs reads it after the last turn. Grammar is scope-derived, so a
// scratch bridge warms the prompt and closes — the child runs its own.
//
//     koruc live_cells.k && ./a.out

import koru/yyjson
import koru/curl
import koru/sse
import std/string
import std/store
import std/fmt
import std/io
import std/fs
import std/interpreter
import std/bridge
import std/runtime
import std/fleet
import std/cell
import std/proto
import app/db_scope
import app/wire

// The conversation so far: escaped, comma-prefixed chat messages, spliced
// between the system message and the current goal.
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }

// This turn's streamed reply, cleared before each ask.
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }

std/proto(child_state) { turns: u32 }

std/fleet:new(node, scope: "db", world: "cells", capacity: 4)

// One SSE delta -> the reply String. Called from inside the arm that still
// owns `doc`, which is the whole difference between this and `d_turns.k`'s
// point-free version — that one RETURNS the extracted text and hands back
// freed memory (wired/holes/3_extracted_string_is_a_borrow_that_escapes).
// The hazard is the escape, so this simply does not escape.
tor collect { text: string<*> }
collect = std/store:query(reply)
! query buf |> std/string:append(s: buf, text)
    | ok |> _
    | err _ |> _

tor handle-delta { payload: string }
// Per-turn terminal reporter. Measured 2026-09-05 (hole 4): OpenRouter sends
// the terminal choices payload TWICE per turn — once bare (finish_reason set,
// usage null) and once with usage attached (same finish_reason, ~500 bytes
// longer). sse:feed and curl await/poll deliver faithfully (counted live:
// every distinct payload exactly once), so the doubling is provider shape,
// not a toolchain defect — consumers key on it, not on events. This prints
// NOTHING for content chunks and bare terminals, exactly one summary line
// for the usage-bearing event. A bare terminal whose usage twin never
// arrives prints nothing; that stream is broken anyway (empty reply).
tor note-usage { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value }
note-usage = koru/yyjson:object.get(doc, v: r, key: "usage")
| found u |> koru/yyjson:object.get(doc, v: u, key: "prompt_tokens")
    | found pv |> koru/yyjson:as.int(doc, v: pv)
        | ok p |> koru/yyjson:object.get(doc, v: u, key: "completion_tokens")
            | found cv |> koru/yyjson:as.int(doc, v: cv)
                | ok c |> koru/yyjson:object.get(doc, v: u, key: "completion_tokens_details")
                    | found dt |> koru/yyjson:object.get(doc, v: dt, key: "reasoning_tokens")
                        | found rv |> koru/yyjson:as.int(doc, v: rv)
                            | ok rt |> report-full(doc, r, p, c, rt)
                            | wrong-type |> _
                        | not-found |> report-part(doc, r, p, c, why: "no reasoning split")
                    | not-found |> report-part(doc, r, p, c, why: "no details")
                | wrong-type |> _
            | not-found |> _
        | wrong-type |> _
    | not-found |> _
| not-found |> _

// Summary printers. Usage numbers arrive as owned i64 bindings and thread
// down as tor params; finish_reason is a borrow printed inside the owning
// arm (never escapes — hole 3's rule). The descent repeats per printer:
// shared would need returning the borrow, which is the banned shape.
tor report-full { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value, p: i64, c: i64, rt: i64 }
report-full = koru/yyjson:object.get(doc, v: r, key: "choices")
| found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
    | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "finish_reason")
        | found fv |> koru/yyjson:as.string(doc, v: fv)
            | ok fr |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} reasoning {{ rt:d }} finish: {{ fr:s }}") |> std/io:free(content: fr)
            | wrong-type |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} reasoning {{ rt:d }} finish: ?")
        | not-found |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} reasoning {{ rt:d }} finish: ?")
    | out-of-range |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} reasoning {{ rt:d }} finish: ?")
| not-found |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} reasoning {{ rt:d }} finish: ?")

tor report-part { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value, p: i64, c: i64, why: string }
report-part = koru/yyjson:object.get(doc, v: r, key: "choices")
| found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
    | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "finish_reason")
        | found fv |> koru/yyjson:as.string(doc, v: fv)
            | ok fr |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} ({{ why:s }}) finish: {{ fr:s }}") |> std/io:free(content: fr)
            | wrong-type |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} ({{ why:s }}) finish: ?")
        | not-found |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} ({{ why:s }}) finish: ?")
    | out-of-range |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} ({{ why:s }}) finish: ?")
| not-found |> std/io:print.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} ({{ why:s }}) finish: ?")

handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> note-usage(doc, r) |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> collect(text: t) |> std/io:free(content: t) |> koru/yyjson:close(doc)
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
// The guidance rides with the vocabulary: app/db_scope's own session facts
// instead of the notes-shaped prose agent-body carries by default.
tor ask { model: string, max_tokens: u32, temperature: string, goal: string }
ask = std/store:query(transcript)
! query h |> std/fmt:fmt.blk {
{{ h:S }}
    } : hist |> app/db_scope:guidance(): g |> app/wire:agent-body-g(model, max_tokens, temperature, goal, history: hist, guidance: g): body |> send(req: body)

// Append this turn to the conversation, so the next one can reason from it.
tor record { goal: string, said: string<*> }
record = std/store:query(transcript)
! query h |> app/wire:msg(role: "user", content: goal): m1 |> std/string:append(s: h, text: m1)
    | ok |> app/wire:msg(role: "assistant", content: said): m2 |> std/string:append(s: h, text: m2)
        | ok |> _
        | err _ |> _
    | err _ |> _

// What the child's bridge did, as a message the next turn will see.
//
// Role "user" rather than "tool": the OpenAI-shaped `tool` role needs a
// tool_call id, and this agent's tool call is a line of Koru rather than a
// function-call object. The `[tool result]` prefix is doing that work instead
// — honest about what it is, and the model reads it fine.
tor observe { text: string<*@scoped> }
observe = std/store:query(transcript)
! query h |> app/wire:msg(role: "user", content: text): m |> std/string:append(s: h, text: m)
    | ok |> _
    | err _ |> _

// The seed: the language shown by example — ONE assistant turn carrying a
// program over this scope's own verbs (app/db_scope:seed). Guidance names
// the shape in prose; the seed SHOWS it, and a model that would otherwise
// answer in prose or a tool-call dialect imitates the wire line.
tor seed {}
seed = std/store:query(transcript)
! query h |> app/db_scope:seed(): st |> app/wire:msg(role: "assistant", content: st): m |> std/string:append(s: h, text: m)
    | ok |> _
    | err _ |> _

// Run what the model said INSIDE THE CHILD and tell it what happened.
//
// cell:run re-tiers the bridge's nine failure arms to one `| error` —
// RunError.kind names the class, message carries the bridge's own teaching
// text. Every arm reports: a refusal the agent never hears about is a
// refusal it will repeat.
tor act { c: *std/cell:Cell<cell>, goal: string, source: string<*> }
act = record(goal, said: source) |> std/cell:run(c, source)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/io:print.ln("  child ok — returned {{ v:s }}, its bridge now holds {{ r.handles:d }} resource(s)")
    |> std/fmt:fmt.blk {
[tool result] ok, it ran and returned {{ v:s }}. The session now holds {{ r.handles:d }} open resource(s).
    } : ma |> observe(text: ma)
| defined d |> std/io:print.ln("  child defined {{ d:s }} — its vocabulary now includes it")
    |> std/fmt:ln("[tool result] defined: '{{ d:s }}' is now a verb in this session's vocabulary — you can call it on a later turn."): mi
    |> observe(mi.text)
| error e |> std/io:print.ln("  child {{ e.kind:s }}: {{ e.message:s }}")
    |> std/fmt:fmt.blk {
[tool result] {{ e.kind:s }}: {{ e.message:s }}
    } : mb |> observe(text: mb)
| unhandled-branch ub |> std/io:print.ln("  child UNHANDLED: branch '{{ ub.branch:s }}' fired with {{ ub.payload:s }}; held {{ ub.handles:s }}")
    |> std/fmt:fmt.blk {
[tool result] Your fragment ran but did not handle the outcome '{{ ub.branch:s }}' (it returned {{ ub.payload:s }}). The session still holds {{ ub.handles:s }} — those are yours to use on the next turn. Read the outcome and continue.
    } : mu |> observe(text: mu)
| residue r |> std/io:print.ln("  child emitted prose — bound as residue: {{ r.report:s }}")
| partial p |> std/io:print.ln("  child steps: {{ p.ran:d }}/{{ p.total:d }} ran, its bridge holds {{ p.handles:d }}")
    |> std/fmt:fmt.blk {
[tool result] Your turn ran as {{ p.total:d }} step(s); {{ p.ran:d }} completed. Step report:
{{ p.report:s }}Open resources: {{ p.handles:d }}.
    } : mp |> observe(text: mp)

// Read what the model said, run it through the child's bridge, and record
// the outcome. `c` is a borrow — the fleet owns the cell; a turn uses it,
// it does not discharge it.
tor drive { c: *std/cell:Cell<cell>, goal: string }
drive = std/store:query(reply)
! query buf |> std/fmt:fmt.blk {
{{ buf:S }}
    } : raw |> std/io:print.ln("  raw  > [{{ raw:s }}]") |> app/wire:clean(raw)
    | ok cs |> std/fmt:fmt.blk {
{{ cs:S }}
    } : src |> std/io:print.ln("  child< {{ src:s }}")
        |> act(c, goal, source: src)
        |> std/string:free(s: cs)
    | err e |> std/io:print.ln("  could not snapshot the reply: {{ e:s }}")

// Clear the in-flight reply before the next ask.
tor clear-reply {}
clear-reply = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

// One turn against the child: borrow it from the fleet, ask the model,
// run its reply through the cell. The borrow ends with the turn; custody
// stays in the index.
tor child-turn { model: string, max_tokens: u32, temperature: string, n: u32, goal: string }
child-turn = std/fleet(node.child-1)
| cell c |> clear-reply()
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  goal: {{ goal:s }}")
    |> ask(model, max_tokens, temperature, goal)
    |> drive(c, goal)
| not-found |> std/io:print.ln("child-1 missing at turn {{ n:d }}")

// Fleet borrows root a chain, never ride one (KORU161): spawn, the
// custody read, and drain each get a tor whose body starts at the
// transform.
tor spawn-child {}
spawn-child = std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "child-1", cell: child_state)
  | spawned b |> std/io:print.ln("--- child-1 resident on scope db, world cells/")
  | resident |> std/io:print.ln("child-1 already resident")
  | refused |> std/io:print.ln("child-1 spawn refused")

tor read-holds {}
read-holds = std/io:print.ln("--- turns done; the child's custody record:")
|> std/fs:read-lines(path: "cells/child-1/holds.log")
    ! line l |> std/io:print.ln("holds: {{ l:s }}")
    | done nl |> std/io:print.ln("— {{ nl:d }} custody event(s)")
    | failed fl |> std/io:print.ln("holds.log unread: {{ fl:s }}")

tor drain-fleet {}
drain-fleet = std/fleet(node)
| fleet f |> std/fleet:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")

// The db session over a spawned child — live_db's custody arc, one
// generation down. A scratch bridge renders the prompt's grammar and
// closes: the vocabulary lives on the scope, not on whichever bridge
// renders it. Then the fleet mints child-1, turns drive its own bridge,
// and the parent reads its holds.log before draining the fleet.
tor converse { model: string, max_tokens: u32, temperature: string }
converse = std/bridge:create(id: "kopium-grammar", scope: "db"): br
|> app/wire:warm-grammar(br)
|> std/bridge:close(br)
|> std/io:print.ln("--- prompt grammar warmed; spawning child-1")
|> spawn-child()
|> child-turn(model, max_tokens, temperature, n: 1, goal: "Open the sqlite database at /tmp/live_cells.db with open-db — a bare call returns the minted token to you; say() output does not come back.")
|> child-turn(model, max_tokens, temperature, n: 2, goal: "Using the connection from turn 1 (it is still open — pass the rN name the report bound as conn:), create a table pets(id INTEGER, name TEXT) with sql and insert two pets. sql is the rowless writer.")
|> child-turn(model, max_tokens, temperature, n: 3, goal: "Query SELECT id, name FROM pets with rows — that spends the connection for the stream. Read each row's columns with col-int and col-text, step with next-row, and when | done hands the connection back, arm it. Then say the pet names.")
|> child-turn(model, max_tokens, temperature, n: 4, goal: "Try col-text(stmt: 'h:Statement:999', index: 0) — a stream token nobody issued. Then explain what happened with say.")
|> child-turn(model, max_tokens, temperature, n: 5, goal: "Close the live connection with close-db — the fresh token from the last done or finish-stmt arm, not the spent one. Then say the session is clean.")
|> read-holds()
|> drain-fleet()

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
                | ok k |> app/wire:bearer(key: k): auth |> std/io:free(content: k) |> app/wire:remember(auth) |> koru/yyjson:close(doc) |> seed() |> converse(model: "poolside/laguna-s-2.1:free", max_tokens: 10000, temperature: "0")
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
