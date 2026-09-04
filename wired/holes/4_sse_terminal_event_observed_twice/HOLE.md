# Hole 4 — the terminal SSE event is observed twice

**Found:** 2026-09-04, instrumenting `live.k` with per-turn usage reporting.
**Confidence it's real:** ~55% (a counted mismatch with a live confound —
see below; the settler is a ten-line probe, not an argument).

## What it looks like

Every live turn prints its `[usage]` line and its `[wire-note]
finish_reason:` line **twice**, with byte-identical numbers:

```
turn 1  goal: Open a note called agent-notes.txt.
  [wire-note] finish_reason: stop
  [usage] prompt 464 completion 554 reasoning 513
  [wire-note] finish_reason: stop
  [usage] prompt 464 completion 554 reasoning 513
```

Against that, a direct Python read of the same provider's stream
(`meta/muse-spark-1.3-contributor`, `stream: true`,
`stream_options: {include_usage: true}`) shows exactly **two** data
events — one choices-only, one choices+usage — then `[DONE]`. One
usage-bearing event on the wire, two usage prints in the program.

## Why it is worth a hole of its own

The content path shows no doubling — `raw == model` on every green
turn — so whatever duplicates does not duplicate *everything*. Two
readings survive, and they point at different repos:

1. **The provider sends an extra copy on real streams.** The Python
   probe used a 22-token prompt and no transcript; the live turns
   carry the system prompt, derived grammar, and growing transcript.
   OpenRouter may attach usage to the final content chunk *and* send
   it standalone on longer streams. That is provider shape, not our
   bug — but then the program should expect it.
2. **`koru/sse:feed` (or the `curl:await` loop) delivers the terminal
   data event twice** — once per chunk boundary, once at finish/flush.
   That is a toolchain defect, and it is worse than cosmetic: a
   duplicated *content* delta would double-append to the reply String
   (`collect` has no dedup), forging ghosts out of real bytes. Today
   only the idempotent observers visibly double; the accumulator
   downstream would not be so lucky.

## The want

Single delivery of each SSE data event — or the terminal shape
documented as multi-event so consumers can key on it. Today neither
holds: the duplication is silent and unexplained.

## Repro

```bash
# 1. The wire, counted (no Koru involved — sets the expectation at two):
python3 -c "
import json, urllib.request
auth = json.load(open('/Users/larsde/.pi/agent/auth.json'))
key = auth['openrouter']['key']
body = json.dumps({'model': 'meta/muse-spark-1.3-contributor',
  'max_tokens': 60, 'stream': True,
  'stream_options': {'include_usage': True},
  'messages': [{'role': 'user', 'content': 'say hi'}]}).encode()
req = urllib.request.Request(
  'https://openrouter.ai/api/v1/chat/completions', data=body,
  headers={'Authorization': 'Bearer ' + key,
           'Content-Type': 'application/json'})
r = urllib.request.urlopen(req, timeout=90)
n = sum(1 for chunk in r for line in chunk.split(b'\n')
        if line.strip().startswith(b'data:'))
print('data events:', n)"
# 2. The program, counted (one live run — cheap, ~6 turns):
cd headless && koruc live.k && ./a.out 2>&1 | sort | uniq -c | sort -rn | head
# Every [usage]/[wire-note] line has count 2; every model> line has count 1.
```

## The settler (not yet run)

Print (or count) the raw `payload` per `handle-delta` call for one
turn: identical bytes twice → the feed/await loop duplicates, fix in
koru (`koru/sse`, `koru/curl`); two distinct events → provider shape,
handle in kopium (key the usage print on first-seen id). A canned-bytes
probe straight through `sse:feed` counting `! data` firings would
settle it with zero tokens and no network.
