// Increment B-zero, a network-free probe — feed fabricated SSE bytes through app/sse:feed and the
// handle-delta ladder, no network — now through koru-libs/sse's handle:
// expected output is "AB" then "probe done".

import std/io
import koru/sse
import koru/yyjson

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
| err e |> std/io:print.ln("probe: delta parse failed: {{ e.msg:s }}")

koru/sse:new(): s |> koru/sse:feed(s, bytes: "data: {\"choices\":[{\"delta\":{\"content\":\"A\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"B\"}}]}\n\ndata: [DONE]\n\n")
! data d |> handle-delta(payload: d)
| ok |> std/io:print.ln("") |> koru/sse:close(s) |> std/io:print.ln("probe done")
