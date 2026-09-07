# Scenario: watch-shortcut-growth (2026-09-07)

Scenario in one sentence (can be wrong): a night-watch log with three
identical sensor readings begs for an invented shortcut verb that appends
handle+text, then the shortcut is repurposed mid-session to speak instead
of write — run against a prompt that actually teaches Growth.

## Prompt provenance (the reframe vs #1/#2)

Worktree `live-define-003` was created fresh from clean base `af63fde`,
then the single file `headless/wire.kz` from the main tree (uncommitted,
carries the Growth teaching at lines 261–267) was copied over the
worktree's `headless/wire.kz` on 2026-09-07. `grep -c Growth
headless/wire.kz` = 1 before building. All other edits and the run happened
in the worktree; the main tree stays untouched.

Toolchain drift, disclosed: the installed `koruc` 0.1.7 was rebuilt
2026-09-07 04:33 from the koru repo and its new KORU116 lint (redundant
phantom qualifier) rejects both the base and the main-tree sources, so this
run could not compile verbatim. Four mechanical, semantics-preserving fixes
were applied in the worktree only, exactly as the compiler hint prescribes
(bare phantom resolves to the same module): `live.k` tor sigs
`Doc<koru/yyjson:open>` → `Doc<open>` (3×), `wire.kz` clean-arm
`String<std/string:view!>` → `String<view!>` (1×). No prompt text, grammar,
bridge, or goal logic was altered for this.

## Goal sequence (5 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

Payoff framing like #2, quoting the prompt's own Growth exception in the
goals; no goal scripts the model's exact reply — not even the verb name:

1. `Open a note called watch-log.txt.`
2. `Three sensor readings must go into the note you opened: 'sensor-a 01:00
   nominal', 'sensor-b 02:00 nominal', 'sensor-c 03:00 nominal'. Logging them
   one append at a time is repetitive, so first teach the session a
   shortcut: invent a verb that takes a handle and a text and appends the
   text to the handle. Reminder: your session rules allow Growth — teaching
   the session a new verb. A definition is the one reply that is TWO lines:
   the first line starts with 'tor' and declares the verb and its params,
   the second line is its body over verbs you already hold; the run loop
   installs it instead of dispatching it. Define the verb now; you will use
   it on the next turns.` (intended: DEFINE, model-chosen name and syntax)
3. `Use the shortcut verb you defined to log 'sensor-a 01:00 nominal' into
   note_0.` (intended: USE)
4. `Repurpose your shortcut verb under the same name so that instead of
   writing into a note it speaks the text aloud. Again, Growth allows it: a
   definition is the one TWO-line reply — a tor line declaring the verb and
   its params, then a body line over verbs you hold. Redefine it now.`
   (intended: REDEFINE, same name)
5. `Use your redefined verb to speak 'night round done'.` (intended: RE-USE)

## What the model defined and redefined

Turn 1 opened note_0 normally. Turn 2 is the catalog's first live DEFINE
attempt — the Growth teaching worked:

- T2 raw: `tor log { handle: string, text: string }` /
  `log = append(handle: handle, text: text)` — model-invented name `log`,
  correct two-line shape, but the body trips the pun rule: `parse-error
  "redundant explicit label 'handle:' — the value 'handle' already puns to
  'handle'"`. Nothing installed (the Growth example `say(text: msg)` never
  shows a same-name label+value, so the model had no passing pattern to copy
  for a two-param pass-through).
- T3–T5 refused via say(), each correctly diagnosing the cascade: "the log
  verb was not installed - my definition failed on redundant label handle:
  handle, so I have no shortcut verb yet" / "I have no log verb to
  repurpose because the earlier definition failed to install" / "no log verb
  was ever installed."

All turns finish_reason stop; bridge state consistent (1 resource
throughout); no live DEFINED, no invention dispatch, no redefine. Exit 0.

## What the catalog learns

New vs #1 (verbatim-scripting refusal) and #2 (one-line-law refusal with no
Growth in the prompt): with the Growth exception actually present in the
system prompt, payoff framing gets the model to CHOOSE define live — the
refusal moved one layer down, from "definitions are impossible" to a
concrete grammar error in the invented body. The next replay should vary the
teaching, not the world: a Growth example showing a same-name
pass-through body (`append(handle, text)` bare-pun shape), or a goal reminder
that names the pun rule, would test whether the attempt converts. Verdict:
honest near-miss — done-gates not met, recorded as-is.

## Operator disclosure

Exactly one live session ran (koruc exit 0, binary timestamp verified fresh
Sep 7 04:39 before execution, ./a.out exit 0). No full50; small spend (5
turns, max completion 4278). No secrets in either file (grep-checked).
headless/live.k goal edits + wire.kz Growth copy + four KORU116 bare-phantom
fixes stay uncommitted in this worktree; main tree untouched. Standards note:
repo-root CLAUDE.md and AGENTS.md are absent (both missing at this base too)
— continued per instructions. challenges/model-sweep/catalog/ does not exist
at this base — noted.
