# Scenario: malformed-input-cased (2026-09-25)

First libs-workbench replay arc. Scenario in one sentence: a model
operating only through the `libs` wire vocabulary (read / edit / write /
check / test / board / say, corpus-rooted at `/Users/larsde/src/koru-libs`)
cases an uncased self-verifying test — `gzip/tests/malformed_input.kz` —
and the suite's own board grades it: 13/13 → 14/14, history "1 fixed".

## Verdict

**PASS, across three sessions and two toolchain fixes.** The corpus the
model edited is committed in koru-libs `1e5f1bb`; the loop that closed it
ran entirely through the wire.

## What the arc actually was

The one-line summary hides the honest shape — the task did not complete
in one session, and the failures are the finding:

- **Replay A (crashed turn 2).** `fmt:ln`'s 4096-byte scratch buffer
  panicked rendering the transcript — reading suite.k (3.8KB) into
  conversation blew it. Domain finding: the notes world keeps transcripts
  small; a file-editing world puts whole files in context. Fixed in the
  driver with `fmt.blk` (the panic's own prescribed API) at every
  unbounded render — transcript snapshot, reply, payload/report arms in
  `act`. Not a workaround: `blk` exists for exactly this.
- **Replay B (task incomplete, real gap surfaced).** Model emitted both
  `edit()` calls at T5 with `\n` escapes in `new_text` — and the wire
  carried them as literal backslash-n into the files. `board()` at T6
  caught it: `PARSE001` on suite.k. First measurement of a real wire gap:
  escapes were *admitted* by the lexer (for boundary detection) but
  *unjudged* by eval — fifth instance of the class
  `frag-the-wire-is-a-grammar-not-a-convention` catalogs. Fixed koru-side:
  `unescapeStringLiteral` at materialization (interpreter.literal.kz,
  koru `d32edc308`); pinned consumer-side in `probe_libs.k`.
- **Replay C (task landed, corpus red).** Steering firmed ("emit BOTH
  edit() calls in this one reply") — model cased the test: markers +
  suite.k entry, one turn. But board read 13/14: the *file itself* had a
  latent `PARSE003` (`~tor` payload spelled `[]const u8`, never compiled
  because never cased) and the marker was missing its `text:` label
  (masked by the compile error). Also observed: at T6 the model piped
  board to `say()` — a one-way channel — and at T7 confabulated "already
  14/14" against a red board it never saw. Second channel finding of the
  project: `say` output is not fed back; a bare call returns its value.
- **Repair 1.** board() bare → model read the diagnostic → composed
  `edit(msg: string) + board()` in one reply → next layer surfaced:
  `PARSE006` on the unlabeled `expect(...)`, the compiler's own hint
  spelling the fix.
- **Repair 2.** Same arc → model fixed the label → board: **14/14**,
  "FIXED — was ✗, now ✓".

## Numbers

- Sessions: 5 live + 1 canned probe pass (8/8 steps incl. the escape pin).
- Turns: 6 (crash) + 6 + 7 + 3 + 3.
- Toolchain defects fixed en route: 2 (fmt scratch ceiling on unbounded
  renders — driver-side; wire string escapes — compiler-side).
- Corpus defects the oracle caught: 2 (latent PARSE003, missing label).
- Final board: **14/14**, one new case green on first scoring run.
- Model confabulations: 1 (T7 "already 14/14" — the say-swallow misfire;
  the repair arc's "call board() bare" steering eliminated the cause).

## What this establishes

The loop is real end to end: the agent read real source, learned an
idiom from a sibling, edited, verified against the suite's own board, and
repaired against the compiler's own diagnostics — nothing mocked, every
verdict a named branch or a real exit code. And the fog-of-war property
held: the oracle caught what the model couldn't see (the masked label
defect only surfaced once the compile error was fixed — layered truth).

## Open edges for the next replay

- `say` swallowing values: the prompt should teach "a bare call returns
  its value to you" — or `say` should echo into the tool result. The
  confabulation class lives wherever the channel is one-way.
- Edit pacing at temp 0: the model defers risky writes past their goal
  turn when uncertain. Whether that's healthy caution or a steering tax
  is a sweep question.
- The workbench has no `remove` verb — scratch files persist (probes
  clean up after themselves out-of-band). A real replay that leaves junk
  in the corpus is honest noise today.

## Artifacts

- `transcript-replay4.log` — the landing session (T4 double-edit, T6 red
  board, T7 confabulation).
- `transcript-repair1.log` — board→diagnose→edit→board in one arc.
- `transcript-repair2.log` — the label fix; board verified out-of-band
  14/14 (koru-libs `1e5f1bb`).
- `headless/libs.kz` — the scope; `headless/probe_libs.k` — the canned
  pin (incl. the escape witness); `headless/live_libs.k` — the driver.
