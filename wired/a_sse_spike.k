// kopium increment A — a Claude reply streams to stdout, token by token.
//
// "koru"-"pi"-"uhmmm": the pi coding-agent harness, reborn in koru. This is
// the tracer bullet for the whole critical path, and every stage of it is a
// library exercised the way kopium will lean on it for real:
//
//   ~/.pi/agent/auth.json --std/io:read-file--> yyjson (key extraction)
//   --> curl:multi.add.post (authenticated POST, stream:true)
//   --> curl:await ! chunk (bytes as they arrive — the arm landed 2026-07-31)
//   --> koru/sse:feed ! data (SSE line framing, per-stream handle)
//   --> yyjson per delta (choices[0].delta.content)
//   --> std/io:print, no newline — the tokens appear as the model types.
//
// Provider is OpenRouter routing to an Anthropic model: the one live key on
// this machine (pi's own auth store), and a real pi provider besides — the
// spike reads its credentials from the very harness it is porting.
//
// FINDINGS pinned by this increment (the charter's real product) — plus
// the three compiler bugs it flushed out and got fixed upstream the same
// day (koru 400_177/178, 400_179, 400_180):
//   - no std/env: the auth path is hardcoded absolute because HOME cannot
//     be read. Same hole class as gitgazer's no-std-process.
//   - SSE framing wanted a koru-libs home — it got one: koru-libs/sse,
//     lifted from this increment's app-local first draft. bearer-concat
//     still waits in app/auth.
//   - the miss-arm ladder in handle-delta: every not-found rung must spell
//     its own close(doc). Honest, but the shape yearns for a combinator.
//   - anthropic/claude-fable-5 via OpenRouter→Bedrock streamed EMPTY
//     deltas (content and reasoning both '', finish=stop) on 2026-07-31 —
//     reproduced with plain curl, so provider-side, not kopium's.
//
//   koruc run a_sse_spike.k
//
// Expected: a short cheerful sentence appears word by word, then a blank
// line, "[status 200]", and a clean exit — the leak check went green the
// day the 335_042 ruling landed (read-file's buffer now carries
// allocated!, auto-discharged into std/io:free with zero edits here).

import std/io
import app/auth
import koru/sse
import koru/curl
import koru/yyjson

// One SSE data payload -> the delta text inside it, printed without a
// newline. Payloads without choices[0].delta.content (role announcements,
// finish-reason chunks, usage tails) are the protocol's designed states —
// each rung closes the doc and moves on, silently and on purpose.
tor handle-delta { payload: string }
handle-delta = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "choices")
    | found cs |> koru/yyjson:array.get(doc, v: cs, index: 0)
        | found c0 |> koru/yyjson:object.get(doc, v: c0, key: "delta")
            | found dv |> koru/yyjson:object.get(doc, v: dv, key: "content")
                | found tv |> koru/yyjson:as.string(doc, v: tv)
                    | ok t |> std/io:print("{{ t:s }}") |> koru/yyjson:close(doc)
                    | wrong-type |> koru/yyjson:close(doc)
                | not-found |> koru/yyjson:close(doc)
            | not-found |> koru/yyjson:close(doc)
        | out-of-range |> koru/yyjson:close(doc)
    | not-found |> koru/yyjson:close(doc)
| err e |> std/io:print.ln("kopium: delta parse failed: {{ e.msg:s }}")

// The streaming POST. One transfer in the batch, pumped by the blocking
// twin (`await`) because this increment is headless — increment B swaps in
// `poll` under a vaxis tick, and THIS TOR DOES NOT CHANGE SHAPE.
tor stream { auth: string }
stream = koru/sse:new(): s |> koru/curl:multi.new()
|> koru/curl:multi.add.post(url: "https://openrouter.ai/api/v1/chat/completions", body: "{\"model\":\"anthropic/claude-haiku-4.5\",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with one short cheerful sentence announcing that kopium is streaming.\"}]}", headers: &.{ .{ .name = "Content-Type", .value = "application/json" }, .{ .name = "Authorization", .value = auth } })
|> koru/curl:multi.start()
| started p |> koru/curl:await(p)
    ! chunk ch |> koru/sse:feed(s, bytes: ch.data)
        ! data d |> handle-delta(payload: d)
        | ok |> _
    ! finished r |> std/io:print("\n[status {{ r.status:d }}]\n") |> koru/curl:close(resp: r)
    | done m |> koru/curl:multi.close(m) |> koru/sse:close(s)
| failed e |> std/io:print.ln("kopium: start failed: {{ e.msg:s }}") |> koru/sse:close(s)

// Load the OpenRouter key from pi's auth store, build the bearer header
// (a COPY — the key is a borrow into doc's arena), close the doc, stream.
std/io:read-file(path: "/Users/larsde/.pi/agent/auth.json")
| ok auth_json |> koru/yyjson:parse(text: auth_json)
    | ok doc |> koru/yyjson:root(doc): r |> koru/yyjson:object.get(doc, v: r, key: "openrouter")
        | found orv |> koru/yyjson:object.get(doc, v: orv, key: "key")
            | found kv |> koru/yyjson:as.string(doc, v: kv)
                | ok k |> app/auth:bearer(key: k): auth |> koru/yyjson:close(doc) |> stream(auth)
                | wrong-type |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: openrouter key is not a string")
            | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter.key in auth store")
        | not-found |> koru/yyjson:close(doc) |> std/io:print.ln("kopium: no openrouter entry in auth store")
    | err e |> std/io:print.ln("kopium: auth store parse failed: {{ e.msg:s }}")
| not-found |> std/io:print.ln("kopium: no ~/.pi/agent/auth.json — log into pi first")
| failed m |> std/io:print.ln("kopium: auth store read failed: {{ m:s }}")
