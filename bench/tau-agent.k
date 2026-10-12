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
// path. Request shape: stream:true, reasoning effort none, usage requested.

import std/io
import std/fmt
import std/store
import std/string
import std/bridge
import std/interpreter
import app/airline_tools
import app/airline_native
import app/corpus_env
import app/tau_wire
import koru/sse
import koru/curl
import headless/wire
import koru/yyjson

// The conversation so far: escaped, comma-prefixed chat messages spliced
// after the system message in each request.
std/store:new(transcript, capacity: 2) { *std/string:String<instance!> }

// This turn's streamed reply, cleared before each ask.
std/store:new(reply, capacity: 2) { *std/string:String<instance!> }



tor collect { text: string<*> }
collect = std/store:query(reply)
! query buf |> std/string:append(s: buf, text)
    | ok |> _
    | err e |> app/tau_wire:die(msg: e)

// The SSE terminal payload carries usage; fold it into the counters the
// next outbound line will carry.
tor note-usage { doc: *koru/yyjson:Doc<open>, r: *koru/yyjson:Value }
note-usage = koru/yyjson:object.get(doc, v: r, key: "usage")
| found u |> koru/yyjson:object.get(doc, v: u, key: "prompt_tokens")
    | found pv |> koru/yyjson:as.int(doc, v: pv)
        | ok p |> koru/yyjson:object.get(doc, v: u, key: "completion_tokens")
            | found cv |> koru/yyjson:as.int(doc, v: cv)
                | ok c |> koru/yyjson:object.get(doc, v: u, key: "cost")
                    | found fv |> koru/yyjson:as.double(doc, v: fv)
                        | ok cost |> app/tau_wire:add-usage(p, c, cost, has_cost: true)
                            |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }}")
                        | wrong-type |> app/tau_wire:add-usage(p, c, cost: 0.0, has_cost: false)
                            |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }}")
                    | not-found |> app/tau_wire:add-usage(p, c, cost: 0.0, has_cost: false)
                        |> std/io:eprint.ln("  [usage] prompt {{ p:d }} completion {{ c:d }}")
                | wrong-type |> _
            | not-found |> _
        | wrong-type |> _
    | not-found |> _
| not-found |> _

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
send = app/tau_wire:auth(): auth |> koru/sse:new(): s |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> handle-delta(payload: d)
        | ok |> _
    ! finished r |> koru/curl:close(resp: r)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> koru/sse:close(s) |> std/fmt:fmt.blk {
        transport failed: {{ e.msg:s }}
    }: m |> app/tau_wire:die(msg: m)

// Build this turn's request from transcript + the boot kernel, receipt it,
// then fire. The grammar/vocabulary/contract the old arm pushed into the
// system message now lives behind the wire's own pull verbs — the kernel
// set at boot is the whole static surface.
tor ask { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string }
ask = std/store:query(transcript)
! query h |> std/fmt:fmt.blk {
        {{ h:S }}
    }: hist
        |> app/tau_wire:body(model, max_tokens, temperature, history: hist): req
        |> app/tau_wire:mark-call-start()
        |> app/tau_wire:write-receipt(body: req)
        | written |> send(req) |> app/tau_wire:usage-check()
        | skipped |> app/tau_wire:die(msg: "KOPIUM_RECEIPT_DIR unset — receipts are mandatory")
        | failed m |> app/tau_wire:die(msg: m)

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
| unhandled-branch { branch: string, payload: string, handles: string }
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
    | defined d => defined d
    | partial p => partial { p.ran, p.total, p.used, p.handles, p.report, p.wire_failures }
    | unhandled-branch ub => unhandled-branch { ub.branch, ub.payload, ub.handles }
    | dispatch-error e => dispatch-error { e.event_name, e.message, e.trace }
    | event-denied ev => event-denied ev
    | residue r => residue { r.report, r.observer, r.bound, r.text }
    | parse-error p => parse-error { p.message, p.line, p.column }
    | validation-error v => validation-error v
    | shape-error sh => shape-error { sh.branch, sh.field, sh.message }
    | exhausted e => exhausted { e.used, e.last_event, e.handles }
    | scope-not-found s2 => scope-not-found s2
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
    }: m
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
    ! query buf |> std/fmt:fmt.blk {
        {{ buf:S }}
    }: raw
        |> std/io:eprint.ln("  wire> {{ raw:s }}")
        |> app/tau_wire:write-response(text: raw)
        | written |> act(br, source: raw)
        | skipped |> act(br, source: raw)
        | failed m |> act(br, source: raw)
| toolcall |> app/tau_wire:tooltake()
    | programs raw |> std/io:eprint.ln("  wire> {{ raw:s }}")
        |> app/tau_wire:write-response(text: raw)
        | written |> act(br, source: raw)
        | skipped |> act(br, source: raw)
        | failed m |> act(br, source: raw)
    | none |> no-program()

// The toolcall reply carried no koru program — a rejected turn, observed
// back like any other.
tor no-program {}
no-program = observe(role: "user", text: "no koru program in the reply — emit one koru tool call whose program is wire text; `vocabulary()` lists every verb")
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
                    observer: {{ nf:d }} consecutive replies reached nobody. `say:` reaches the user, `note:` thinks, `verb(field: ...)` calls — `vocabulary()` lists every verb. In one line: what are you waiting for?
                }: m |> observe(role: "user", text: m)
                    |> loop(br, model, max_tokens, temperature, bound, fails, silents: nf)
                | retry nf |> loop(br, model, max_tokens, temperature, bound, fails, silents: nf)
                | over |> app/tau_wire:die(msg: "10 consecutive replies reached neither the user nor a tool")
    | rejected |> app/tau_wire:saw-eof()
        | yes |> app/tau_wire:session-end()
        | no |> app/tau_wire:bump-fail(n: fails, bound)
            | edge nf |> std/fmt:fmt.blk {
                observer: {{ nf:d }} consecutive refused replies. `say:` reaches the user, `note:` thinks, `verb(field: ...)` calls — `vocabulary()` lists every verb. In one line: what were you trying to do?
            }: m |> observe(role: "user", text: m)
                |> loop(br, model, max_tokens, temperature, bound, fails: nf, silents: 0)
            | retry nf |> loop(br, model, max_tokens, temperature, bound, fails: nf, silents: 0)
            | over |> app/tau_wire:die(msg: "the wire rejected 10 consecutive replies")

tor clear-reply {}
clear-reply = std/store:query(reply)
! query buf |> std/string:clear(s: buf)

// The seed: the language shown first — five lines of wire in one prior
// turn (say/note spelling, the pull verb, a fielded call, an rN
// reference) — then the vocabulary dumped behind it, enclosed in the
// result shape exactly as a real vocabulary() pull would return it. No
// kernel, no rules: the verbs are in context, the verdicts teach the rest.
tor seed { vocab: string }
seed = observe(role: "assistant", text: "say: Booked — your flight is confirmed, economy.\nnote: user confirmed; the certificate covers the fare.\nvocabulary()\nget-user-details(user_id: \"example_user_0\")\nbook-reservation(user_id: \"example_user_0\", flights: r9.flights, payment_methods: [{payment_id: \"example_cert_0\", amount: 250}], total_baggages: 3, nonfree_baggages: 0, insurance: \"no\")")
    |> headless/wire:seed-result(value: vocab, bound: "r2"): m
    |> observe(role: "user", text: m)

// Boot: init (policy — observed in-band as the first transcript entry, no
// system message, no pushed doc) then the seeded example turn plus the
// live vocabulary render, then the first user line. Everything else the
// wire needs arrives through the gate's own refusals and pull verbs.
tor boot { br: *std/bridge:Bridge<session>, model: string, max_tokens: u32, temperature: string, bound: i64 }
boot = app/tau_wire:inbound()
| init p |> observe(role: "user", text: p)
    |> std/bridge:vocabulary(br)
    | ok v |> seed(vocab: v) |> app/tau_wire:inbound()
        | user u |> observe-human(text: u) |> app/tau_wire:auth-ensure()
            | ok |> loop(br, model, max_tokens, temperature, bound, fails: 0, silents: 0)
            | failed m |> app/tau_wire:die(msg: m)
        | init _ | app/tau_wire:die(msg: "second init line")
        | result _ | app/tau_wire:die(msg: "result with no outstanding call")
        | eof |> app/tau_wire:session-end()
        | bad m |> app/tau_wire:die(msg: m)
    | not-found s2 |> app/tau_wire:die(msg: s2)
| user _ | app/tau_wire:die(msg: "expected init line first")
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

app/tau_wire:scope-name(): sc
|> app/corpus_env:env-or(key: "KOPIUM_WORLD", fallback: ""): w
|> [with]std/bridge:create(id: "tau-agent", scope: sc, introspection: true, world: w): br
|> app/tau_wire:model-name(): m
|> boot(br, model: m, max_tokens: 16384, temperature: "0", bound: 10)
