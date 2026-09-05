// PROBE, not a deliverable — hole 4's settler, one live turn.
//
// Question: does the Koru stack (curl await + sse:feed + handle-delta) deliver
// each SSE data event exactly once? Prints one fingerprint block per `! data`
// firing: U (usage key present?), F (finish_reason string or none), C
// (delta.content present?), L (payload byte length). Identical blocks twice
// in a row = a duplicated delivery; two terminal blocks with different L =
// the provider's bare-then-usage shape, faithfully delivered.
//
// Prints borrow inside the owning arm (increments-A/B pattern) — no escapes.
// live.k's send/ask/auth shape, single turn, then exit.
import std/io
import std/string
import koru/sse
import koru/curl
import koru/yyjson
import app/wire

tor has-usage { doc: *koru/yyjson:Doc<koru/yyjson:open>, r: *koru/yyjson:Value }
has-usage = koru/yyjson:object.get(doc, v: r, key: "usage")
| found u |> koru/yyjson:object.get(doc, v: u, key: "prompt_tokens")
    | found _ |> std/io:print.ln("U:1")
    | not-found |> std/io:print.ln("U:0-null")
| not-found |> std/io:print.ln("U:0")

tor has-finish { doc: *koru/yyjson:Doc<koru/yyjson:open>, c0: *koru/yyjson:Value }
has-finish = koru/yyjson:object.get(doc, v: c0, key: "finish_reason")
| found fv |> koru/yyjson:as.string(doc, v: fv)
    | ok fr |> std/io:print.ln("F:{{ fr:s }}") |> std/io:free(content: fr)
    | wrong-type |> std/io:print.ln("F:null")
| not-found |> std/io:print.ln("F:none")

tor has-content { doc: *koru/yyjson:Doc<koru/yyjson:open>, c0: *koru/yyjson:Value }
has-content = koru/yyjson:object.get(doc, v: c0, key: "delta")
| found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
    | found _ |> std/io:print.ln("C:1")
    | not-found |> std/io:print.ln("C:0")
| not-found |> std/io:print.ln("C:0")

tor print-len { payload: string }
print-len = std/string:from-page(text: payload)
| ok a |> std/string:take(s: a): h |> std/string:len(s: h): n |> std/io:print.ln("L:{{ n:d }}") |> std/string:free(s: h)
| err _ |> std/io:print.ln("L:?")

tor finger { payload: string }
finger = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> has-usage(doc, r) |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> has-finish(doc, c0) |> has-content(doc, c0) |> print-len(payload) |> koru/yyjson:close(doc) |> std/io:print.ln("--")
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err _ |> _

tor send { req: string }
send = app/wire:recall(): auth |> koru/sse:new(): s |> koru/curl:multi.new() |> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: req, headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } }) |> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> finger(payload: d)
        | ok |> _
    ! finished r |> koru/curl:close(resp: r)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> std/io:print.ln("transport failed: {{ e.msg:s }}") |> koru/sse:close(s)

std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/wire:bearer(key: k): auth |> std/io:free(content: k) |> app/wire:remember(auth) |> koru/yyjson:close(doc) |> app/wire:agent-body(model: "meta/muse-spark-1.3-contributor", max_tokens: 2000, temperature: "0", goal: "say hi in one short sentence", history: ""): body |> send(req: body)
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
