// tau-agent.k — the tau2 airline agent. The ONLY thing Python does for this
// arm is spawn this binary and copy lines in and out (bench/kopium_agent.py
// is a marshal, nothing else): the model call, the transcript, the prompt,
// the gate, the retry bound, and usage accounting all live here.
//
// Wire protocol (line-delimited JSON; stdout is protocol, stderr is log):
//   in : {"kind":"init","policy":...} once, then {"kind":"user",...} /
//        {"kind":"result","id":...,"content":...}
//   out: {"kind":"say",...} / {"kind":"call","id","name","arguments"} — emitted
//        by the procs themselves mid-`run`; say blocks for the user's reply,
//        a call blocks for its result. See app/tau_wire.
//
//   koruc tau-agent.k   → a.out is the agent binary.
//
// Reuses headless/wire only for message shaping (msg). The model's reply
// reaches std/bridge:run RAW — no fence or whitespace laundering on this
// path. Request shape: stream:true, usage requested; reasoning effort comes
// from KOPIUM_REASONING (default medium) and "none" omits the field entirely.

import std/io
import std/fmt
import std/env
import std/store
import std/string
import std/bridge
import std/interpreter
import app/airline_tools
import app/airline_native
import app/corpus_env
import app/tau_wire
import app/db_scope
import koru/sse
import koru/curl
import headless/wire
import koru/yyjson

// The conversation so far: escaped, comma-prefixed chat messages spliced
// after the system message in each request.
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }

// This turn's streamed reply, cleared before each ask.
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }

// The init's domain policy, wrapped once at boot and spliced into the
// system render after the grammar on every ask — domain law with the
// contract's authority, not a user message mid-history. Empty when no
// init has arrived.
std/store:new(domain_policy, capacity: 2) { *std/string:String<instance!> }



tor collect { text: string<*> }
collect = std/store:query(reply)
! query buf |> std/string:append(s: buf, text)
    | ok |> _
    | err e |> app/tau_wire:die(msg: e)

// The SSE terminal payload carries usage; fold it into the counters the
// next outbound line will carry. `cost` is OpenRouter's billed figure —
// already net of any cache discount; `cached_tokens` (from
// prompt_tokens_details) records the cached share of the prompt so the
// receipts can say what the discount actually was.
tor note-usage { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value }
note-usage = koru/yyjson:object.get(doc, v: r, key: "usage")
| found u |> koru/yyjson:object.get(doc, v: u, key: "prompt_tokens")
    | found pv |> koru/yyjson:as.int(doc, v: pv)
        | ok p |> koru/yyjson:object.get(doc, v: u, key: "completion_tokens")
            | found cv |> koru/yyjson:as.int(doc, v: cv)
                | ok c |> note-usage-cached(doc, u, p, c)
                | wrong-type |> _
            | not-found |> _
        | wrong-type |> _
    | not-found |> _
| not-found |> _

tor note-usage-cached { doc: *koru/yyjson:Doc<open>, u: *koru/yyjson:Value, p: i64, c: i64 }
note-usage-cached = koru/yyjson:object.get(doc, v: u, key: "prompt_tokens_details")
| found pd |> koru/yyjson:object.get(doc, v: pd, key: "cached_tokens")
    | found ctv |> koru/yyjson:as.int(doc, v: ctv)
        | ok cached |> note-usage-cost(doc, u, p, c, cached)
        | wrong-type |> note-usage-cost(doc, u, p, c, cached: 0)
    | not-found |> note-usage-cost(doc, u, p, c, cached: 0)
| not-found |> note-usage-cost(doc, u, p, c, cached: 0)

tor note-usage-cost { doc: *koru/yyjson:Doc<open>, u: *koru/yyjson:Value, p: i64, c: i64, cached: i64 }
note-usage-cost = koru/yyjson:object.get(doc, v: u, key: "cost")
| found fv |> koru/yyjson:as.double(doc, v: fv)
    | ok cost |> app/tau_wire:add-usage(p, c, cost, has_cost: true, cached)
        |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} cached {{ cached:d }}")
    | wrong-type |> app/tau_wire:add-usage(p, c, cost: 0.0, has_cost: false, cached)
        |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} cached {{ cached:d }}")
| not-found |> app/tau_wire:add-usage(p, c, cost: 0.0, has_cost: false, cached)
    |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }} cached {{ cached:d }}")

// Toolcall channel: `choices[0].delta.tool_calls[].function.arguments`
// streams in as string fragments — each entry's fragment accumulates into
// the per-index buffer in tau_wire (missing `index` = slot 0), and `take`
// extracts each call's `program` field at end-of-turn.
tor one-toolcall { doc: *koru/yyjson:Doc<open>, t0: *koru/yyjson:Value }
one-toolcall = koru/yyjson:object.get(doc, v: t0, key: "index")
| found iv |> koru/yyjson:as.int(doc, v: iv)
    | ok ix |> one-toolcall-args(doc, t0, index: ix)
    | wrong-type |> _
| not-found |> one-toolcall-args(doc, t0, index: 0)

tor one-toolcall-args { doc: *koru/yyjson:Doc<open>, t0: *koru/yyjson:Value, index: i64 }
one-toolcall-args = koru/yyjson:object.get(doc, v: t0, key: "function")
| found fv |> koru/yyjson:object.get(doc, v: fv, key: "arguments")
    | found av |> koru/yyjson:as.string(doc, v: av)
        | ok t |> app/tau_wire:toolfrag(index, text: t)
        | wrong-type |> _
    | not-found |> _
| not-found |> _

tor note-toolcalls { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value }
note-toolcalls = koru/yyjson:object.get(doc, v: r, key: "choices")
| found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
    | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
        | found dv |> koru/yyjson:object.get(doc, v: dv, key: "tool_calls")
            | found tc |> koru/yyjson:array.each(doc, v: tc)
                ! item t0 |> one-toolcall(doc, t0)
                | done |> _
                | not-an-array |> _
            | not-found |> _
        | not-found |> _
    | out-of-range |> _
| not-found |> _

tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> note-usage(doc, r) |> note-toolcalls(doc, r) |> koru/yyjson:object.get(doc, v: r, key: "choices")
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

// The streaming POST — same shape as live.k's send.
tor send { req: string }
send = app/tau_wire:api-url(): u |> app/tau_wire:auth(): auth |> koru/sse:new(): s |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: u, body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> app/tau_wire:buffer-resp(ch.data) |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> handle-delta(payload: d)
        | ok |> _
    ! finished r |> koru/curl:status(resp: r): st |> koru/curl:close(resp: r) |> app/tau_wire:transport-check(status: st)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> koru/sse:close(s) |> std/fmt:fmt.blk {
        transport failed: {{ e.msg:s }}
    }: m |> app/tau_wire:die(msg: m)

// Fold the init's policy into the system suffix `ask` renders. The
// policy is the domain's law — every action judged against these rules,
// records read against these conditions — so it rides the system
// message, not a user-role turn.
tor policy-note { text: string<*> }
policy-note = std/store:query(domain_policy)
! query dp |> std/fmt:fmt.blk {

DOMAIN POLICY — the rules every action must satisfy. Judge each request
against these conditions, reading them against the records you fetch.

{{ text:s }}
    }: dptxt
    |> std/string:append(s: dp, text: dptxt)
        | ok |> _
        | err e |> app/tau_wire:die(msg: e)

// Drain the bridge's call_step JSONL to the side channel after each run —
// one file per drain under KOPIUM_RECEIPT_DIR, origin-stamped ("harness"
// for the agent's own grammar() read, "model" for agent-emitted wires).
tor drain-calls { br: *std/bridge:Bridge<session>, origin: string }
drain-calls = std/bridge:take-calls(br) |> app/tau_wire:write-callsteps(origin)
| written |> _
| skipped |> _
| failed m |> app/tau_wire:die(msg: m)

// Build this turn's request from the transcript, receipt it, then fire.
// The system's surface — grammar rules, the live vocabulary, the domain
// policy — is the system message, rendered fresh on every ask and
// spliced ahead of the transcript: the same declaration the gate
// enforces, given to the model rather than fetched, and never stale — a
// `defined` flow joins the render the very next turn.
tor ask { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string }
ask = std/store:query(transcript)
! query h |> std/bridge:grammar(br)
    | ok g |> drain-calls(br, origin: "harness") |> std/store:query(domain_policy)
        ! query dp |> std/fmt:fmt.blk {
{{ g:s }}{{ dp:S }}
            }: sysg |> headless/wire:msg(role: "system", content: sysg): sysmsg
            |> app/tau_wire:body(model, max_tokens, temperature, syshead: sysmsg, history: h): req
            |> app/tau_wire:mark-call-start()
            |> app/tau_wire:write-receipt(body: req)
            | written |> send(req) |> app/tau_wire:usage-check()
            | skipped |> app/tau_wire:die(msg: "KOPIUM_RECEIPT_DIR unset — receipts are mandatory")
            | failed m |> app/tau_wire:die(msg: m)
    | not-found s2 |> app/tau_wire:die(msg: s2)

// Append a chat message to the transcript.
tor observe { role: string, text: string<*> }
observe = std/store:query(transcript)
! query h |> headless/wire:msg(role, content: text): m |> std/string:append(s: h, text: m)
    | ok |> _
    | err e |> app/tau_wire:die(msg: e)

tor observe-human { text: string<*> }
observe-human = std/fmt:fmt.blk {
        user: {{ text:s }}
    }: m |> observe(role: "user", text: m)

// Run what the model wrote and report the outcome back verbatim — the
// bridge's own diagnostic words, no authored coaching.
tor run-capped { br: *std/bridge:Bridge<session>, source: string<*> }
| result { value: @import("root").koru_std.koru_interpreter.Value, used: u64, handles: u32, bound: string, trace: string }
| defined string
| unhandled-branch { branch: string, payload: string, handles: string, guides: string }
| exhausted { used: u64, last_event: string, handles: u32 }
| parse-error { message: string, line: u32, column: u32 }
| residue { report: string, observer: bool, bound: string, text: string }
| validation-error string
| shape-error { branch: string, field: ?string, message: string }
| event-denied string
| dispatch-error { event_name: string, message: string, trace: string }
| ?partial { ran: u32, total: u32, used: u64, handles: u32, report: string, wire_failures: u32 }
| scope-not-found string

run-capped = app/tau_wire:item-cap(source, max: 128)
| ok _ |> std/bridge:run(br, source)
    | result r => result { r.value, r.used, r.handles, r.bound, r.trace }
    | error e |> std/bridge:error-decode(e)
        | dispatch-error de => dispatch-error { de.event_name, de.message, de.trace }
        | event-denied ev => event-denied ev
        | parse-error p => parse-error { p.message, p.line, p.column }
        | validation-error v => validation-error v
        | shape-error sh => shape-error { sh.branch, sh.field, sh.message }
        | exhausted ex => exhausted { ex.used, ex.last_event, ex.handles }
        | scope-not-found s2 => scope-not-found s2
        | unknown-error u => dispatch-error { event_name: "", u.message, trace: "" }
    | defined d => defined d
    | partial p => partial { p.ran, p.total, p.used, p.handles, p.report, p.wire_failures }
    | unhandled-branch ub => unhandled-branch { ub.branch, ub.payload, ub.handles, ub.guides }
    | residue r => residue { r.report, r.observer, r.bound, r.text }
| over _ => exhausted { used: 0, last_event: "turn item cap exceeded", handles: 0 }

tor act { br: *std/bridge:Bridge<session>, source: string<*> }
act = observe(role: "assistant", text: source) |> run-capped(br, source)
| result r |> std/interpreter:value.stringify(r.value): v
    |> std/fmt:fmt.blk {
        {{ r.trace:s }}result: {{ v:s }} bound: {{ r.bound:s }}
    }: m |> observe(role: "user", text: m)
    |> app/tau_wire:count-out(kind: "result")
| defined d |> std/fmt:fmt.blk {
        defined: {{ d:s }}
    }: m |> observe(role: "user", text: m)
    |> app/tau_wire:count-out(kind: "define")
| partial p |> observe(role: "user", text: p.report)
    |> app/tau_wire:count-residue(text: p.report)
    |> app/tau_wire:partial-verdict(p.wire_failures)
    | clean |> app/tau_wire:count-out(kind: "partial")
    | dirty |> app/tau_wire:count-rejection(kind: "partial")
| unhandled-branch ub |> std/fmt:fmt.blk {
        unhandled-branch: {{ ub.branch:s }} — {{ ub.payload:s }} (held {{ ub.handles:s }}). An arm word must be a branch name — `ok` binds an ordinary result, a named branch binds under its own name; no other arm word matches.
{{ ub.guides:s }}    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:arm-word(ub.branch)
    | ordinary |> app/tau_wire:count-rejection(kind: "unhandled")
    | named |> app/tau_wire:count-out(kind: "result")
| dispatch-error e |> std/fmt:fmt.blk {
        {{ e.trace:s }}dispatch-error {{ e.event_name:s }}: {{ e.message:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-out(kind: "result")
| event-denied ev |> std/fmt:fmt.blk {
        event-denied: {{ ev:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "event-denied")
| residue r |> observe(role: "user", text: r.report)
    |> app/tau_wire:count-residue(text: r.report)
    |> app/tau_wire:residue-verdict(r.observer, prose: r.text)
    | observer |> app/tau_wire:count-out(kind: "note")
    | strike |> app/tau_wire:count-rejection(kind: "residue")
        |> observe(role: "assistant", text: "say(text: \"One moment — let me check that for you.\")")
| parse-error p |> std/fmt:fmt.blk {
        parse-error: {{ p.message:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "parse-error")
| validation-error v |> std/fmt:fmt.blk {
        validation-error: {{ v:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "validation-error")
| shape-error sh |> std/fmt:fmt.blk {
        shape-error {{ sh.branch:s }}: {{ sh.message:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "shape-error")
| exhausted e |> std/fmt:fmt.blk {
        exhausted: {{ e.last_event:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "exhausted")
| scope-not-found s2 |> std/fmt:fmt.blk {
        scope-not-found: {{ s2:s }}
    }: m
    |> observe(role: "user", text: m)
    |> app/tau_wire:count-rejection(kind: "scope-not-found")

// The toolcall reply's accumulated args text is `{"program": "<wire>"}` —
// the program string is the wire source. A missing/unparseable program is
// a rejected turn, observed back like any other.
tor drive { br: *std/bridge:Bridge<session> }
drive = app/tau_wire:channel()
| content |> std/store:query(reply)
    ! query buf |> std/string:len(s: buf): n |> app/tau_wire:blank(n)
        | empty |> app/tau_wire:write-response(text: "")
            | written |> empty-reply()
            | skipped |> empty-reply()
            | failed m |> empty-reply()
        | wire |> std/fmt:fmt.blk {
            {{ buf:S }}
        }: raw
            |> std/io:eprint.ln("  wire> {{ raw:s }}")
            |> app/tau_wire:write-response(text: raw)
            | written |> act(br, source: raw) |> drain-calls(br, origin: "model")
            | skipped |> act(br, source: raw) |> drain-calls(br, origin: "model")
            | failed m |> act(br, source: raw) |> drain-calls(br, origin: "model")
| toolcall |> app/tau_wire:tooltake()
    | programs raw |> std/io:eprint.ln("  wire> {{ raw:s }}")
        |> app/tau_wire:write-response(text: raw)
        | written |> act(br, source: raw) |> drain-calls(br, origin: "model")
        | skipped |> act(br, source: raw) |> drain-calls(br, origin: "model")
        | failed m |> act(br, source: raw) |> drain-calls(br, origin: "model")
    | none |> no-program()

// Zero bytes reached the wire — not a refused program, a silent turn.
// The model is told plainly (the empty reply is the observable symptom,
// e.g. a reasoning model muted by effort:none), and the strike lands under
// its own kind so session.json separates silence from malformed wire.
tor empty-reply {}
empty-reply = observe(role: "user", text: "your reply carried no wire — emit wire text: `say(text: ...)` reaches the user, `verb(field: ...)` calls; `vocabulary()` lists every verb")
    |> observe(role: "assistant", text: "say(text: \"One moment — let me check that for you.\")")
    |> app/tau_wire:count-rejection(kind: "empty")

// The toolcall reply carried no koru program — a rejected turn, observed
// back like any other.
tor no-program {}
no-program = observe(role: "user", text: "no koru program in the reply — emit one koru tool call whose program is wire text; `vocabulary()` lists every verb")
    |> observe(role: "assistant", text: "say(text: \"One moment — let me check that for you.\")")
    |> app/tau_wire:count-rejection(kind: "residue")

// User replies captured by say() procs mid-run become real user messages
// before the next model call.
tor drain {}
| again
| stop

drain = app/tau_wire:take-pending()
| some u |> observe-human(text: u) |> drain()
    | again => again
    | stop => stop
| none |> app/tau_wire:saw-eof()
    | yes => stop
    | no => again

// The loop: ask, run, report, drain, repeat. EOF ends it; the rejection
// bound dies loud rather than apologizing, and a reply that ran but
// delivered nothing (note-only, residue-only, define-only) ticks the
// sibling silence streak — same edge/over shape, independent counter.
// The lens rung: near either bound, `edge` asks the model for its own
// account — wire or prose, the answer lands in the receipts, so a dying
// run still ships its post-mortem.
tor loop { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string, bound: i64, fails: i64, silents: i64 }
loop = clear-reply()
    |> ask(br, model, max_tokens, temperature)
    |> drive(br)
    |> app/tau_wire:verdict()
    | ran |> app/tau_wire:delivered()
        | said |> app/tau_wire:pull() |> drain()
            | again |> loop(br, model, max_tokens, temperature, bound, fails: 0, silents: 0)
            | stop |> app/tau_wire:session-end() |> std/io:eprint.ln("--- eof, session ends")
        | silent |> drain()
            | stop |> app/tau_wire:session-end() |> std/io:eprint.ln("--- eof, session ends")
            | again |> app/tau_wire:bump-fail(n: silents, bound)
                | edge nf |> std/fmt:fmt.blk {
                    observer: {{ nf:d }} consecutive replies reached nobody. `say(text: ...)` reaches the user, `verb(field: ...)` calls — `vocabulary()` lists every verb. In one line: what are you waiting for?
                }: m |> observe(role: "user", text: m)
                    |> loop(br, model, max_tokens, temperature, bound, fails, silents: nf)
                | retry nf |> loop(br, model, max_tokens, temperature, bound, fails, silents: nf)
                | over |> app/tau_wire:die(msg: "10 consecutive replies reached neither the user nor a tool")
    | rejected |> app/tau_wire:saw-eof()
        | yes |> app/tau_wire:session-end()
        | no |> app/tau_wire:bump-fail(n: fails, bound)
            | edge nf |> std/fmt:fmt.blk {
                observer: {{ nf:d }} consecutive refused replies. `say(text: ...)` reaches the user, `verb(field: ...)` calls — `vocabulary()` lists every verb. In one line: what were you trying to do?
            }: m |> observe(role: "user", text: m)
                |> loop(br, model, max_tokens, temperature, bound, fails: nf, silents: 0)
            | retry nf |> loop(br, model, max_tokens, temperature, bound, fails: nf, silents: 0)
            | over |> app/tau_wire:die(msg: "the wire rejected 10 consecutive replies")

tor clear-reply {}
clear-reply = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

// The seed: the language shown by example — ONE assistant turn carrying a
// program that ends in a `say`. Per-scope (app/tau_wire:seed-text): a seed
// naming a verb outside this vocabulary teaches a refusal, so `db` gets a
// custody-chain seed while airline keeps its user-details lookup. The
// vocabulary itself is not here: it lives in the system message, given,
// never fetched.
tor seed {}
seed = app/tau_wire:seed-text(): st |> observe(role: "assistant", text: st)

// Demo-history injection (prototype, arm B-negative): when KOPIUM_DEMO is
// set, seed the transcript with failure->error->self-correction exchanges
// before the first real turn. Error strings are verbatim system output;
// the recovery demonstrates the mapping. Positive demos are OUT (arm-B
// positive poisoned session state, task-0 FATAL) — these teach recovery,
// not success.
tor demo-seed {}
demo-seed = observe-human(text: "My user ID is DEMO_USER_0001, please look me up.")
    |> observe(role: "assistant", text: "get-user-details(user_id: \"DEMO_USER_0001\") | ok u |>\nsay(text: \"Found you, {{ u.user_id }}!\")")
    |> observe(role: "user", text: "step 1/1 result: {\"branch\":\"error\",\"value\":\"Error: User DEMO_USER_0001 not found\"}")
    |> observe(role: "assistant", text: "get-user-details(user_id: \"demo_user_0001\") | ok u |>\nsay(text: \"Found you, {{ u.user_id }}!\")")
    |> observe(role: "user", text: "step 1/1 result: {\"branch\":\"ok\",\"value\":\"{\\\"user_id\\\": \\\"demo_user_0001\\\", \\\"name\\\": {\\\"first_name\\\": \\\"Demo\\\"}}\"}")

// Arm-B2: wire-only exemplar — the lookup error->retry exchange WITHOUT
// the prose-collapse exemplar. Arm-B's prose turn is the suspected
// collapse trigger (it models the failure mode in the agent's own voice).
tor demo-wire-seed {}
demo-wire-seed = observe-human(text: "My user ID is DEMO_USER_0001, please look me up.")
    |> observe(role: "assistant", text: "get-user-details(user_id: \"DEMO_USER_0001\") | ok u |>\nsay(text: \"Found you, {{ u.user_id }}!\")")
    |> observe(role: "user", text: "step 1/1 result: {\"branch\":\"error\",\"value\":\"Error: User DEMO_USER_0001 not found\"}")
    |> observe(role: "assistant", text: "get-user-details(user_id: \"demo_user_0001\") | ok u |>\nsay(text: \"Found you, {{ u.user_id }}!\")")
    |> observe(role: "user", text: "step 1/1 result: {\"branch\":\"ok\",\"value\":\"{\\\"user_id\\\": \\\"demo_user_0001\\\", \\\"name\\\": {\\\"first_name\\\": \\\"Demo\\\"}}\"}")

tor demo-wire-gate {}
demo-wire-gate = std/env:is-set(name: "KOPIUM_DEMO_WIRE")
    | yes |> demo-wire-seed()
    | no |> _

tor demo-gate {}
demo-gate = std/env:is-set(name: "KOPIUM_DEMO")
    | yes |> demo-seed()
    | no |> _

// Boot: the system message never enters the transcript — `ask` splices a
// fresh `sysdoc` render ahead of the history on every turn, so the
// declared surface the model sees is always live: wire rules, "Your
// vocabulary:" with signatures, the domain policy, and this session's
// defined flows. Boot only stores the policy, seeds the example
// program, and observes the first user turn.
tor boot { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string, bound: i64 }
boot = app/tau_wire:inbound()
| init p |> policy-note(text: p)
    |> seed() |> demo-gate() |> demo-wire-gate() |> app/tau_wire:inbound()
    | user u |> observe-human(text: u) |> app/tau_wire:auth-ensure()
        | ok |> loop(br, model, max_tokens, temperature, bound, fails: 0, silents: 0)
        | failed m |> app/tau_wire:die(msg: m)
    | init _ | app/tau_wire:die(msg: "second init line")
    | wire _ | app/tau_wire:die(msg: "wire line on the agent protocol")
    | result _ | app/tau_wire:die(msg: "result with no outstanding call")
    | eof |> app/tau_wire:session-end()
    | bad m |> app/tau_wire:die(msg: m)
| user _ | app/tau_wire:die(msg: "expected init line first")
| wire _ | app/tau_wire:die(msg: "wire line on the agent protocol")
| result _ | app/tau_wire:die(msg: "result with no outstanding call")
| eof |> app/tau_wire:die(msg: "stdin closed before init")
| bad m |> app/tau_wire:die(msg: m)

// Seed the two session Strings.
std/string:from-page(text: "")
| ok a |> std/string:take(s: a): t |> std/store:insert(transcript) { t }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err e |> app/tau_wire:die(msg: e)

std/string:from-page(text: "")
| ok b |> std/string:take(s: b): u |> std/store:insert(reply) { u }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err e |> app/tau_wire:die(msg: e)

std/string:from-page(text: "")
| ok c |> std/string:take(s: c): v |> std/store:insert(domain_policy) { v }
    | row _ |> _
    | full f |> std/string:free(s: f)
| err e |> app/tau_wire:die(msg: e)

app/tau_wire:scope-name(): sc
|> app/corpus_env:env-or(key: "KOPIUM_WORLD", fallback: ""): w
|> [with]std/bridge:create(id: "tau-agent", scope: sc, introspection: true, world: w): br
|> app/tau_wire:model-name(): m
|> boot(br, model: m, max_tokens: 16384, temperature: "0", bound: 10)
