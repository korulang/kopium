// PROBE — the promote gate: a verb earns its place in the genome or it does
// not land. The selection leg heredity left open, proven against existing
// pieces with a canned replay — no model, no spend.
//
// The protocol, translated from harness2's probe-then-adopt:
//
//   1. Session A mounts `gate-stage/` — a STAGING world. It does the
//      open/append/close dance by hand across three turns, then defines
//      `log-line`. The define writes `gate-stage/log-line.k`: the candidate
//      is staged, not promoted.
//   2. Session B mounts `gate-base/` (empty) and replays the pinned case by
//      hand — three dispatches, the handle crossing turns as a literal —
//      the baseline receipt.
//   3. Session C mounts the stage, calls the one-word verb — one dispatch —
//      the candidate receipt.
//   4. Session D mounts `gate-stage-bad/`, which holds a hand-gardened
//      `leaky-line` — a VALID Koru body that opens and never closes. The
//      install-time obligation-honesty edge is still open, so the replay is
//      what catches it: its receipt carries the hold it left.
//   5. `judge` compares each candidate against the baseline. PROMOTE lands
//      `gate-world/log-line.k` plus a required-field `.promote.md` sidecar.
//      DROP lands nothing — KEEP_BASE is a real verdict.
//   6. Session E mounts `gate-world/` — the heir sees `log-line` and is
//      denied `leaky-line`. The genome kept only what earned it.
//
//   rm -rf gate-stage gate-stage-bad gate-base gate-world gate-log.txt \
//     && koruc probe_promote.k && ./a.out && cat gate-world/*.promote.md
//
// The gate module (gate.kz) holds the tally because flow state cannot count
// across turns; judge returns a branch because the verdict is a routing
// decision, not prose. (First run taught the receipt's first law: a chained
// single-source dance is ONE dispatch — the baseline must be the real
// multi-turn hand dance or the contrast is invisible.)

import std/bridge
import std/io
import std/fmt
import app/notes
import app/gate

// One replay: dispatch the source, count what the bridge said, show it. Every
// verdict arm is named — a wall firing is data, not noise.
tor gated { br: *std/bridge:Bridge<session>, source: string<*>, tag: string }
gated = std/bridge:run(br, source)
| result r |> app/gate:step(tag, ran: 1, holds: r.handles)
    |> std/io:print.ln("  [{{ tag:s }}] ok — {{ r.handles:d }} held")
| partial p |> app/gate:step(tag, p.ran, holds: p.handles)
    |> std/io:print.ln("  [{{ tag:s }}] {{ p.ran:d }}/{{ p.total:d }} ran — {{ p.handles:d }} held")
| defined d |> app/gate:defined(tag)
    |> std/io:print.ln("  [{{ tag:s }}] defined {{ d:s }} — staged, not promoted")
| dispatch-error e |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] REFUSED: {{ e.message:s }}")
| unhandled-branch ub |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] UNHANDLED: {{ ub.branch:s }}")
| event-denied ev |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] DENIED: {{ ev:s }}")
| residue r2 |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] residue: {{ r2.report:s }}")
| parse-error p2 |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] parse-error: {{ p2.message:s }}")
| exhausted _ |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] exhausted")
| validation-error v |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] invalid: {{ v:s }}")
| shape-error s |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] shape: {{ s.message:s }}")
| scope-not-found s2 |> app/gate:refusal(tag)
    |> std/io:print.ln("  [{{ tag:s }}] no such scope: {{ s2:s }}")

// A turn whose source needs the handle the bridge just minted — the probe
// binds it through last-minted exactly as a cooperative model binds it from
// the observation, never guessing.
tor append-wire { text: string, handle: string } -> string<std/io:allocated!>
append-wire = std/fmt:fmt.blk {
        append(handle: "{{ handle:s }}", text: "{{ text:s }}")
    }: m -> m

tor close-wire { handle: string } -> string<std/io:allocated!>
close-wire = std/fmt:fmt.blk {
        close(handle: "{{ handle:s }}")
    }: m -> m

tor gated-append { br: *std/bridge:Bridge<session>, text: string, tag: string }
gated-append = app/notes:last-minted(): h
    |> append-wire(text, handle: h): src
    |> gated(br, source: src, tag)

tor gated-close { br: *std/bridge:Bridge<session>, tag: string }
gated-close = app/notes:last-minted(): h
    |> close-wire(handle: h): src
    |> gated(br, source: src, tag)

// The verdict act: judge routes, land writes the genome + sidecar on promote.
tor gateone { name: string, cand: string, base: string, cue: string, stage: string }
gateone = app/gate:judge(name, cand, base)
| promote why |> std/io:print.ln("[gate] PROMOTE {{ name:s }} — {{ why:s }}")
    |> app/gate:land(name, cand, base, stage, world: "gate-world", cue)
| drop why2 |> std/io:print.ln("[gate] DROP {{ name:s }} — {{ why2:s }} — nothing lands")

[with]app/gate:seed(path: "gate-stage-bad/leaky-line.k", content: "tor leaky-line { path: string, text: string }\nleaky-line = open(path)\n| ok h |> append(handle: h, text)")
|> std/io:print.ln("--- staged a leaky candidate by hand-gardening (the genome is a directory)")
|> std/bridge:create(id: "stage", scope: "notes", world: "gate-stage"): a
|> std/io:print.ln("--- A: invents into the staging world")
|> gated(br: a, source: "open(path: \"gate-log.txt\")", tag: "stage")
|> gated-append(br: a, text: "by hand, turn two", tag: "stage")
|> gated-close(br: a, tag: "stage")
|> gated(br: a, source: "tor log-line { path: string, text: string }\nlog-line = open(path)\n| ok h |> append(handle: h, text)\n    | ok |> close(handle: h)", tag: "stage")
|> gated(br: a, source: "log-line(path: \"gate-log.txt\", text: \"in one word, while staged\")", tag: "stage")
|> app/gate:verdict(tag: "stage")
|> std/bridge:close(br: a)
|> std/bridge:create(id: "base", scope: "notes", world: "gate-base"): b
|> std/io:print.ln("--- B: baseline — the pinned case, empty world, by hand")
|> gated(br: b, source: "open(path: \"gate-log.txt\")", tag: "base")
|> gated-append(br: b, text: "baseline", tag: "base")
|> gated-close(br: b, tag: "base")
|> app/gate:verdict(tag: "base")
|> std/bridge:close(br: b)
|> std/bridge:create(id: "cand", scope: "notes", world: "gate-stage"): c
|> std/io:print.ln("--- C: the staged candidate world — same case, one word")
|> gated(br: c, source: "log-line(path: \"gate-log.txt\", text: \"candidate replay\")", tag: "cand-good")
|> app/gate:verdict(tag: "cand-good")
|> std/bridge:close(br: c)
|> gateone(name: "log-line", cand: "cand-good", base: "base", cue: "a multi-verb dance worth one word", stage: "gate-stage")
|> std/bridge:create(id: "badcand", scope: "notes", world: "gate-stage-bad"): d
|> std/io:print.ln("--- D: the leaky candidate — a valid body that never closes")
|> gated(br: d, source: "leaky-line(path: \"gate-log.txt\", text: \"leaks a hold\")", tag: "cand-bad")
|> app/gate:verdict(tag: "cand-bad")
|> std/bridge:close(br: d)
|> gateone(name: "leaky-line", cand: "cand-bad", base: "base", cue: "a dance that forgets the close", stage: "gate-stage-bad")
|> std/bridge:create(id: "heir", scope: "notes", world: "gate-world"): e
|> std/io:print.ln("--- E: the heir mounts only what earned promotion")
|> gated(br: e, source: "log-line(path: \"gate-log.txt\", text: \"inherited and promoted\")", tag: "heir-good")
|> gated(br: e, source: "leaky-line(path: \"gate-log.txt\", text: \"should be denied\")", tag: "heir-bad")
|> std/bridge:vocabulary(br: e)
| ok v |> std/io:print.ln("--- E's derived vocabulary:\n{{ v:s }}")
   |> std/bridge:close(br: e)
| not-found s |> std/io:print.ln("!! scope {{ s:s }} vanished")
