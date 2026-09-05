// Hole-4 settler probe (canned bytes, zero tokens).
//
// Feeds a realistic OpenRouter terminal sequence through koru/sse:feed under
// adversarial chunk splits and counts `! data` firings per distinct payload.
// Each firing prints one GOT line; the shell counts them.
//
// Expected if feed is innocent: every distinct payload prints exactly once
// Result 2026-09-05: scenarios 1-3 fire each distinct payload exactly once
// no matter how the bytes split — feed is innocent. Scenario 4 (same bytes
// fed twice) fires twice, correct per contract: feed is a byte framer, not
// an exactly-once layer. Run: koruc run probe.k (needs koru-libs on the
// paths in koru.json; copy the headless one and fix the relative paths).
import std/io
import koru/sse

tor scenario { name: string, a: string, b: string }
scenario = koru/sse:new(): s
    |> koru/sse:feed(s, bytes: a)
        ! data d |> std/io:print.ln("GOT {{ name:s }}:[{{ d:s }}]")
        | ok |> koru/sse:feed(s, bytes: b)
            ! data d |> std/io:print.ln("GOT {{ name:s }}:[{{ d:s }}]")
            | ok |> koru/sse:close(s) |> std/io:print.ln("END {{ name:s }}")

// 1. Terminal sequence split mid-JSON across two feeds.
scenario(name: "split-mid-json", a: "data: {\"id\":\"1\"}\n\ndata: {\"choices\":[],\"usage\":{\"prompt_tokens\":464,\"compl", b: "etion_tokens\":554}}\n\ndata: [DONE]\n\n")

// 2. Split mid-"data:" prefix.
scenario(name: "split-mid-prefix", a: "data: {\"x\":1}\n\nda", b: "ta: {\"usage\":{\"prompt_tokens\":464}}\n\n")

// 3. CRLF line endings + comment keepalive + retry field noise.
scenario(name: "crlf-noise", a: ": OPENROUTER PROCESSING\r\ndata: {\"k\":1}\r\nretry: 1000\r\n\r\n", b: "data: [DONE]\r\n\r\n")

// 4. THE suspect: the same terminal chunk fed TWICE (what a finish/flush
//    re-delivery looks like from feed's side of the fence).
scenario(name: "fed-twice", a: "data: {\"usage\":{\"prompt_tokens\":464}}\n\n", b: "data: {\"usage\":{\"prompt_tokens\":464}}\n\n")

std/io:print.ln("probe done")
