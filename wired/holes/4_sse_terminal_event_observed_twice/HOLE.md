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

## The settler (ran 2026-09-05 — see verdict)

Print (or count) the raw `payload` per `handle-delta` call for one
turn: identical bytes twice → the feed/await loop duplicates, fix in
koru (`koru/sse`, `koru/curl`); two distinct events → provider shape,
handle in kopium (key the usage print on first-seen id). A canned-bytes
probe straight through `sse:feed` counting `! data` firings would
settle it with zero tokens and no network. — RAN 2026-09-05, see verdict.

## Verdict — SETTLED 2026-09-05: provider shape, toolchain cleared

The settler ran, in four layers, and reading 2 (feed/curl duplicates) is
dead:

1. **Canned `sse:feed` probe** (`probe.k` in this directory, zero tokens):
   mid-JSON splits, mid-`data:`-prefix splits, CRLF + keepalive + `retry`
   noise — every distinct payload fires exactly once. Feeding the same
   bytes twice fires twice, which is contract-correct: feed is a byte
   framer, not an exactly-once layer.
2. **`curl await/poll` code-read**: the slot buffer is cleared behind every
   `! chunk` firing; `finished` carries only status + what trailed the
   final drain. No re-delivery path.
3. **Live Koru count** (`headless/probe_hole4.k`, one turn): 7 `! data`
   firings through the full stack, every distinct payload exactly once —
   5 content events, 1 bare terminal, 1 usage terminal.
4. **Wire captures** (Python, short/long/reasoning/natural-stop turns):
   OpenRouter sends the terminal choices payload TWICE — once bare
   (`finish_reason` set, `usage` null) and once with usage attached (same
   `finish_reason`, ~500 bytes longer). Usage itself arrives exactly once
   per turn in all five measured shapes (11-event reasoning turn
   included).

So the `[wire-note]` doubling is explained provider shape: two `F:stop`
events per turn, and any per-event finish print fires twice. Fixed in
kopium, not koru: `headless/live.k` retires the standalone `note-finish`
and keys the summary on the usage-bearing event (`note-usage` →
`report-full`/`report-part`), one line per turn —
`[usage] prompt P completion C reasoning R finish: stop`. The `[DONE]`
sentinel, keepalives, and blank lines stay silent in feed, as before.
The old `[wire-note] finish_reason:` line format is gone; nothing pinned
it (only transcripts and docs referenced it).

**Residual, stated plainly:** the original `[usage]`-printed-twice half of
the symptom is UNREPRODUCED — five wire shapes show one usage event per
turn, and the current consumer prints once per turn in all of them. Best
reading is transient provider behavior on the 09-04 long-reasoning turns
(100k budget), not a delivery bug: every layer that could duplicate was
counted clean. If it recurs, the re-probe is `probe_hole4.k` (live count)
against a long turn — three minutes, fractions of a cent.

**Content-ghost note:** the terminal pair carries empty/absent `content`,
so `collect` appending per event is harmless today. A provider that ever
repeats a NON-empty content chunk would double-append; no measured shape
does. Watch item, not work.
