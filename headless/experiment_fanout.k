// kopium-headless FAN-OUT EXPERIMENT — the re-opener round 3 asked for.
//
// The serial task (open→append→close, one file) measured composition 3× MORE
// expensive than the pre-chain wire, because every step depends on the one
// before it — the chain buys nothing the serial spelling lacks. This variant
// gives composition something to buy: THREE independent files, each its own
// open→append→close. Serial invocation needs ≥9 turns; a composed turn can
// carry all three files' work at once. Same model, same metric, same arms —
// only the task changed. `converse` at the bottom is the only change.
//
// `session.k` is this program with the model canned, so the thing under test
// is the bridge. This is the other half: the invocations are not written down
// anywhere. A live model — named once at the `converse(model:)` call site at
// the bottom of this file, currently meta/muse-spark-1.3-contributor — is
// handed the `notes` vocabulary and a goal, and whatever it emits goes
// straight to `std/bridge:run`.
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
// `wired/a_sse_spike.k` reads.

import std/io
import std/fmt
import std/store
import std/string
import std/bridge
import std/interpreter
import app/notes
import app/wire
import koru/sse
import koru/curl
import koru/yyjson

// The conversation so far: escaped, comma-prefixed chat messages, spliced
// between the system message and the current goal.
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }

// This turn's streamed reply, cleared before each ask.
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }

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
tor ask { model: string, max_tokens: u32, temperature: string, goal: string }
ask = std/store:query(transcript)
! query h |> std/fmt:fmt.blk {
    {{ h:S }}
}: hist |> app/wire:agent-body(model, max_tokens, temperature, goal, history: hist): body |> send(req: body)

// Append this turn to the conversation, so the next one can reason from it.
tor record { goal: string, said: string<*> }
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
tor observe { text: string<*> }
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
tor act { br: *std/bridge:Bridge<session>, goal: string, source: string<*> }
act = record(goal, said: source) |> std/bridge:run(br, source)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/io:print.blk {
        ok — returned {{ v:s }}, bridge now holds {{ r.handles:d }} resource(s)
    } |> std/fmt:fmt.blk {
        [tool result] ok, it ran and returned {{ v:s }}. The session now holds {{ r.handles:d }} open resource(s).
    }: ma |> observe(text: ma)
| defined d |> std/io:print.ln("  defined {{ d:s }} — the session's vocabulary now includes it")
    |> std/fmt:ln("[tool result] defined: '{{ d:s }}' is now a verb in this session's vocabulary — you can call it on a later turn."): mi
    |> observe(mi.text)
| dispatch-error e |> std/io:print.blk {
        REFUSED: {{ e.message:s }} — '{{ e.event_name:s }}' never ran
    } |> std/fmt:fmt.blk {
        [tool result] REFUSED: {{ e.message:s }}. '{{ e.event_name:s }}' did NOT run.
    }: mb |> observe(text: mb)
| unhandled-branch ub |> std/io:print.blk {
        UNHANDLED: branch '{{ ub.branch:s }}' fired with {{ ub.payload:s }}; held {{ ub.handles:s }}
    } |> std/fmt:fmt.blk {
        [tool result] Your fragment ran but did not handle the outcome '{{ ub.branch:s }}' (it returned {{ ub.payload:s }}). The session still holds {{ ub.handles:s }} — those are yours to use on the next turn. Read the outcome and continue, or close what you opened.
    }: mu |> observe(text: mu)
| event-denied ev |> std/io:print.ln("  DENIED — '{{ ev:s }}' is not in this agent's scope")
    |> std/fmt:ln("[tool result] DENIED: '{{ ev:s }}' is not in your vocabulary. Use only the verbs in Your vocabulary above — open, append, close, read, edit, say, and every verb you defined this session."): mc
    |> observe(mc.text)
| residue r |> std/io:print.ln("  residue: {{ r.report:s }}")
| parse-error p |> std/io:print.blk {
        the model did not emit Koru: {{ p.message:s }}
    } |> std/fmt:fmt.blk {
        [tool result] That was not Koru: {{ p.message:s }}. Each line is one invocation; a definition is two lines, the first starting with `tor `.
    }: md |> observe(text: md)
| partial p |> std/io:print.ln("  steps: {{ p.ran:d }}/{{ p.total:d }} ran, bridge holds {{ p.handles:d }}")
    |> std/fmt:fmt.blk {
        [tool result] Your turn ran as {{ p.total:d }} step(s); {{ p.ran:d }} completed. Step report:
        {{ p.report:s }}Open resources: {{ p.handles:d }}.
    }: mp |> observe(text: mp)
| exhausted _ |> std/io:print.ln("  budget exhausted")
    |> observe(text: "[tool result] budget exhausted; nothing ran.")
| validation-error v |> std/io:print.blk {
        invalid: {{ v:s }}
    } |> std/fmt:fmt.blk {
        [tool result] invalid invocation: {{ v:s }}
    }: mf |> observe(text: mf)
| shape-error sh |> std/io:print.blk {
        wrong shape: {{ sh.message:s }}
    } |> std/fmt:fmt.blk {
        [tool result] wrong shape: {{ sh.message:s }}
    }: mg |> observe(text: mg)
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
// it went into `record`, into `std/bridge:run`, and out through the arms,
// each of which can run arbitrary model-chosen `notes` events. Nothing stopped
// one of those from appending to `reply` and reallocating the bytes `src`
// points at, with the owner alive the whole time and no free anywhere
// (610_008). `clean` now returns an owned String: `cs` is a local nothing
// downstream can reach, and it dies on one visible line after the last use.
//
// The whole turn travels now (frag-partial-programs): a reply may hold several
// invocations, a two-line declaration, or a chain, and `std/bridge:run`
// sequences it. There is no drop to warn about — `extra-lines` is retired.
tor drive { br: *std/bridge:Bridge<session>, goal: string }
drive = std/store:query(reply)
! query buf |> std/fmt:fmt.blk {
    {{ buf:S }}
}: raw |> std/io:print.blk {
    raw  > [{{ raw:s }}]
} |> app/wire:clean(raw)
    | ok cs |> std/fmt:fmt.blk {
        {{ cs:S }}
    }: src |> std/io:print.blk {
        model> {{ src:s }}
    } |> act(br, goal, source: src)
        |> std/string:free(s: cs)
    | err e |> std/io:print.ln("  could not snapshot the reply: {{ e:s }}")

// Clear the in-flight reply before the next ask.
tor clear-reply {}
clear-reply = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

// One turn. `br` carries no phantom — a turn USES the session, it does not
// end it.
//
// After the turn runs, `fanout-done` reads all three files and prints one
// machine-readable marker per file. `append` writes straight to the fd, so
// the bytes are on disk before any close; the runner sums `[usage]` up to the
// first turn where all three markers show their expected bytes — and, for
// the strict metric, where the bridge also reports 0 held.
tor check-one { n: u32, path: string, tag: string }
check-one = std/io:read-file(path)
| ok content |> std/io:print.ln("turn-check {{ n:d }} {{ tag:s }}: [{{ content:s }}]")
    |> std/io:free(content)
| not-found |> std/io:print.ln("turn-check {{ n:d }} {{ tag:s }}: missing")
| failed e |> std/io:print.ln("turn-check {{ n:d }} {{ tag:s }}: failed {{ e:s }}")

tor fanout-done { n: u32 }
fanout-done = check-one(n, path: "exp-a.txt", tag: "a")
    |> check-one(n, path: "exp-b.txt", tag: "b")
    |> check-one(n, path: "exp-c.txt", tag: "c")

tor turn { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string, n: u32, goal: string }
turn = app/wire:warm-grammar(br)
    |> clear-reply()
    |> std/io:print.ln("")
    |> std/io:print.ln("turn {{ n:d }}  goal: {{ goal:s }}")
    |> ask(model, max_tokens, temperature, goal)
    |> drive(br, goal)
    |> fanout-done(n)

// The fan-out variant: THREE independent files, each open→append→close. The
// serial wire needs ≥9 turns; a composed turn can carry all three at once —
// that is the case round 3 left open. Twelve turns of headroom so the serial
// arm is never capped before it can legally finish. Goals identical across
// arms; only `app/wire` (and for pre-chain, the toolchain) differs.
tor converse { model: string, max_tokens: u32, temperature: string }
converse = std/bridge:create(id: "kopium-experiment", scope: "notes"): br
|> std/io:print.ln("--- experiment: three notes, write alpha/beta/gamma, close all ---")
|> turn(br, model, max_tokens, temperature, n: 1, goal: "Create three notes: exp-a.txt containing the line 'alpha', exp-b.txt containing 'beta', and exp-c.txt containing 'gamma'. Close all of them.")
|> turn(br, model, max_tokens, temperature, n: 2, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 3, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 4, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 5, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 6, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 7, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 8, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 9, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 10, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 11, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open.")
|> turn(br, model, max_tokens, temperature, n: 12, goal: "Continue the task. exp-a.txt must hold 'alpha', exp-b.txt 'beta', exp-c.txt 'gamma', and no note may be open. You are done when all three hold their bytes and nothing is open. If it is already done, call say(text: \"already done\").")
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
                | ok k |> app/wire:bearer(key: k): auth |> std/io:free(content: k) |> app/wire:remember(auth) |> koru/yyjson:close(doc) |> converse(model: "meta/muse-spark-1.3-contributor", max_tokens: 20000, temperature: "0")
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
