# Scenario: double-entry-late-bind (2026-09-23)

Scenario in one sentence (can be wrong): a double-entry ledger where every
posting must be filed twice forces a SECOND defined verb whose body calls
the first — then a redefine of the first shows through the untouched second
if the defined-flows table is a live namespace.

## Prompt provenance

Worktree `live-define-007`, fresh from main HEAD `b74be0e`; no file copies
needed. `headless/live.k` goal edits stay uncommitted in the worktree.

## Goal sequence (6 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

Same steering grammar as #4/#5/#6 — Growth reminder + two-line shape +
greet quote + pun warning; no goal scripts the reply:

1. `Open a note called double-entry.txt. Leave it open.`
2. `Teach the session a shortcut: invent a verb that takes a handle and a
   text and appends the text to the handle. [Growth + shape + greet quote
   + pun warning.]` (intended: DEFINE A)
3. `This ledger needs double-entry: every posting must be filed twice in a
   row. Invent a SECOND shortcut verb — same params — whose body calls
   your FIRST shortcut twice with what it was given. Verbs you defined
   are in your vocabulary and callable inside a body, and a body may
   chain calls with |> on one line. [Growth + shape + pun warning still
   apply.]` (intended: DEFINE B ON A — stacking)
4. `Use your second verb to post 'entry 002: sold' into the note you
   hold.` (intended: USE B)
5. `The audit rule changed: every filing must now be preceded by a marker
   line '---'. Redefine your FIRST shortcut verb under the SAME name with
   a NEW body that appends the marker line and then the text it was
   given. It must still append, never speak.` (intended: REDEFINE A)
6. `Use your SECOND verb again — unchanged — to post 'entry 003: settled'
   into the same note, then close the note.` (intended: late binding —
   B's stored body should dispatch the NEW A)

## What the model defined and did not dispatch

- T1: opened `double-entry.txt` → `d81785`, left open.
- T2 raw: `tor jot { h: string, m: string }` /
  `jot = append(handle: h, text: m)` → `defined jot`. Clean.
- T3 raw: `tor double { handle: string, text: string }` /
  `double = jot(h: handle, m: text) |> jot(h: handle, m: text)` →
  `defined double`. Two details: it named the params `handle`/`text` —
  dodging the pun rule by construction (`h: handle` is label≠value) after
  only an abbreviated pun reminder — and it chose the BARE `|>` chain
  shape, which the goal text literally suggested.
- T4: `double(handle: "d81785", text: "entry 002: sold")` → **REFUSED:
  ValidationFailed — 'double' never ran.** The bridge's stderr held the
  real cause — `[REDEFINE-DISPATCH] re-parse of 'double' failed:
  Invalid invocation syntax` — the stored body re-parses per dispatch
  under `flow_parser`, which wants `| arm |>` continuations and does not
  take the bare `|>` the full parser accepted at install. The dispatch-
  time detail never reached the model: the tool result carried only
  `ValidationFailed`.
- T5 raw: `tor jot { h: string, m: string }` /
  `jot = append(handle: h, text: "---") |> append(handle: h, text: m)` →
  `defined jot` — a second bare-`|>` body installed clean, same latent
  refusal. (The proven `| ok q |>` shape was never in this session's
  transcript to copy.)
- T6: the model refused to act via say() and CONFABULATED the cause —
  claimed `double(handle: d81785)` was refused `HandleNotHeld` (an error
  that exists nowhere; T4's refusal was the re-parse), invented the norm
  "passing the literal is predicting, not binding" (it had passed that
  literal at T4), and concluded it holds nothing usable. The note was
  discharged by hang-up at session end. `double-entry.txt` is empty.

All turns finish_reason stop; bridge consistent (1 held resource, hang-up
discharged). Live DEFINED ×3: yes. Live dispatch of an invention: NO.
Redefine + re-dispatch: NO. Exit 0. Done-gates NOT met.

## The canned control (zero-token, same session)

`headless/probe_define_stack.k` (committed beside this entry) drives the
whole arc canned over `say`, twice through `std/bridge:run`:

- Run 1: `tor jot { m: string }` `jot = say(text: m)`; `tor double
  { mm: string }` `double = jot(m: mm) | ok q |> jot(m: mm)`; then
  `double(mm: "first")` → printed `first` `first`. **Stacking works**:
  a defined flow's body resolves an earlier defined name at dispatch,
  chained through the arm shape.
- Run 2: jot redefined to `say(text: "marker") | ok q |> say(text: m)`,
  `double(mm: "second")` unchanged → `marker second marker second`.
  **Late binding holds**: redefining a callee rewires the untouched
  caller — the defined table is a live namespace, not a snapshot. (This
  is the semantics R3's summonable recompile would later need to
  preserve or consciously break.)

## What the catalog learns

Three findings, one at each layer:

1. **Install-time vs dispatch-time grammar delta (toolchain).** Define
   validates the body with the full parser, which accepts `a() |> b()`
   bare-pipe sequencing; dispatch re-parses with `flow_parser.parseFlow`,
   which wants `| arm |>`. A body can install that can never run — a lie
   at install. Floats a ruling: wire grows bare `|>`, or define validates
   with the dispatch grammar so the refusal lands at install. (Per the
   one law this is a koru-side question, not a prompt workaround.)
2. **A dead teaching channel.** The dispatch-time re-parse error prints
   `[REDEFINE-DISPATCH] re-parse of '<name>' failed: <cause>; body was:
   '<body>'` to stderr — the model's tool result carries only
   `REFUSED: ValidationFailed — 'double' never ran`. The one fact that
   would have repaired the next turn existed and wasn't delivered.
   Whether re-parse failures belong in the tool-result channel is a real
   design question — the channel currently filters them out.
3. **The model over-generalized into a norm.** Refused once, at T6 it
   cited a rule that doesn't exist (`HandleNotHeld`, "predicting, not
   binding" for a literal it had already passed) and declined a goal it
   could have met by re-emitting the same call. Without the cause it
   filled the gap with a plausible-sounding law — the failure mode
   `headed.log` exists to catch, now measured on the drive path.

Also measured cheaply along the way: an abbreviated pun reminder
("[pun warning still apply]") was enough — params named `handle`/`text`
dodged by construction; and the mid-program mix (defines + dispatch items
in one `run`) reports cleanly under `?partial` per step.

The next replay has a repaired grammar hint (name the `| ok q |>` arm
shape, not bare `|>`) and can ask the still-open edge: self-reference —
a redefine whose body calls its own name. Verdict: honest near-miss on
the arc, double finding underneath — done-gates not met, recorded as-is.

## Operator disclosure

Exactly one live session ran (koruc exit 0, ./a.out exit 0), plus one
duplicate first turn killed on sight (a stale `a.out` from a failed
sibling probe compile — `koruc | tail` returned tail's status, so `&&`
ran the old binary; the turn was mid-flight at kill, no second-session
interference). No full50; small spend (6 turns, max completion 4268). No
secrets in either file (grep-checked). headless/live.k goal edits stay
uncommitted in the worktree; `probe_define_stack.k` is committed as the
canned witness.
