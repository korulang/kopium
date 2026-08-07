// Hole 3 with the copy, written with EXPLICIT bindings instead of point-free.
// Same six stages, same doc, same extraction — the only change from the
// baseline is that the text is copied into an owned String before `close`,
// and the tor hands back the String handle rather than a borrow.
import std/io
import std/string
import koru/yyjson

tor extract { payload: string }
| ok *std/string:String<std/string:view!>
| gone
extract = koru/yyjson:parse(text: payload)
| ok doc |> koru/yyjson:root(doc): r
    |> koru/yyjson:object.get(doc, v: r, key: "choices")
        | found ch |> koru/yyjson:array.get(doc, v: ch, index: 0)
            | found el |> koru/yyjson:object.get(doc, v: el, key: "delta")
                | found dl |> koru/yyjson:object.get(doc, v: dl, key: "content")
                    | found ct |> koru/yyjson:as.string(doc, v: ct)
                        | ok txt |> std/string:from-page(text: txt)
                            | ok s |> koru/yyjson:close(doc) => ok s
                            | err _ |> koru/yyjson:close(doc) => gone
                        | wrong-type |> koru/yyjson:close(doc) => gone
                    | not-found |> koru/yyjson:close(doc) => gone
                | not-found |> koru/yyjson:close(doc) => gone
            | out-of-range |> koru/yyjson:close(doc) => gone
        | not-found |> koru/yyjson:close(doc) => gone
| err _ => gone

extract(payload: "{\"choices\":[{\"delta\":{\"content\":\"HELLO\"}}]}")
| ok s |> std/string:read(s): t
    |> std/io:print.ln("EXTRACTED: [{{ t:s }}]")
    |> std/string:free(s)
| gone |> std/io:print.ln("GONE — extracted nothing")
