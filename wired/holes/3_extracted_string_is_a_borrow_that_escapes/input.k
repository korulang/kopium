// Does the point-free ladder actually EXTRACT, or does it only compile?
// One fixed OpenRouter-shaped delta, no network.
import std/io
import koru/yyjson

tor extract { payload: string }
| ok string
| gone
extract = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "choices")
    |> koru/yyjson:array.get(doc, index: 0)
    |> koru/yyjson:object.get(doc, key: "delta")
    |> koru/yyjson:object.get(doc, key: "content")
    |> koru/yyjson:as.string(doc)
    | not-found |> koru/yyjson:close(doc) => gone
    | out-of-range |> koru/yyjson:close(doc) => gone
    | wrong-type |> koru/yyjson:close(doc) => gone
| err _ => gone

extract(payload: "{\"choices\":[{\"delta\":{\"content\":\"HELLO\"}}]}")
| ok t |> std/io:print.ln("EXTRACTED: [{{ t:s }}]")
| gone |> std/io:print.ln("GONE — extracted nothing")
