# Scenario: audit-marker-rebind (2026-09-23)

Scenario in one sentence (can be wrong): an audit trail where every filed
line must suddenly be preceded by a marker line forces a same-name redefine
whose new body must USE both params across TWO appends — the first chained
defined-body attempted live — in the file kind the earlier arcs never
redefined within.

## Prompt provenance

Worktree `live-define-006` was created fresh from main HEAD `e52995d` —
no copies needed; the Growth teaching and the derived worked example are
committed at this base. `headless/live.k` goal edits stay uncommitted in
the worktree; the main tree is untouched.

Toolchain detour, disclosed: `live.k` could not compile at this base when
the session started — the hole-8 `__koru_arg_` bound-name mint rewrote
`.m` member positions inside `koru_curl`'s spliced `multi.start` body
(`p.* = .{ .__koru_arg_m_0 = ... }` against the library-declared
`Pending`; "no field named '__koru_arg_m_0'"). Reproduced on the
UNMODIFIED live.k, then pinned koru-side as 230_023 (member position is
not a reference; `0..m`'s range end is the control) and fixed in
`replaceIdentifier` — koru `dcdd7ac70`. The run below compiled under the
fixed koruc. The model, prompt, grammar, and goal text are unaffected —
only the emitted Zig for the collision site differs.

## Goal sequence (6 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

Same steering grammar as #4/#5 — Growth reminder + two-line shape + the
greet example quote + pun warning (params h/m, never `handle: handle` /
`text: text`); no goal scripts the model's exact reply — not even the
verb name:

1. `Open a note called audit-trail.txt. Leave it open.`
2. `Every line filed into the note needs the same handling, so teach the
   session a shortcut: invent a verb that takes a handle and a text and
   appends the text to the handle. [Growth + shape + greet quote + pun
   warning.] Define the verb now; you will use it on the next turns.`
   (intended: DEFINE, model-chosen name)
3. `Use the shortcut verb you defined to file 'entry 001: nominal' into
   the note you hold.` (intended: USE)
4. `The audit rule changed: every filed line must now be preceded by a
   marker line '---'. Redefine your shortcut verb under the SAME name
   with a NEW body that appends the marker line and then the text it was
   given — still appending into the handle it takes, so both params stay
   in use. A body may chain calls with |> on one line, just like your
   replies do. It must still append, never speak. Redefine it now.`
   (intended: REDEFINE, same name, same kind, both params used)
5. `Use your redefined verb to file 'entry 002: amended' into the same
   note.` (intended: RE-USE)
6. `Close the note you hold.` (possession teardown)

## What the model defined and redefined

The catalog's first chained defined-body, and its first full arc in the
file kind:

- T2 raw: `tor log { h: string, m: string }` /
  `log = append(handle: h, text: m)` → `defined log`. Model-chosen name
  `log` (the same name #3's parse-killed attempt chose — this time the
  pun-steering carried it through).
- T3 raw: `log(h: "c50704", m: "entry 001: nominal")` → appended, `ok`.
- T4 raw: `tor log { h: string, m: string }` /
  `log = append(handle: h, text: "---") | ok q |> append(handle: q, text: m)`
  → `defined log` again. The model invented a CHAIN: bind the first
  append's `ok` payload (the handle) into `q`, feed it to the second
  append. Both params used; same kind; nobody scripted `q`.
- T5 raw: `log(h: "c50704", m: "entry 002: amended")` → dispatched the
  NEW body. The artifact on disk proves the rebinding took effect:
  `entry 001: nominal` / `---` / `entry 002: amended` — the marker
  precedes only the post-redefine entry.
- T6: clean close; bridge holds 0.

All turns finish_reason stop; bridge state consistent (1 resource held
turns 1–5, discharged on 6). Live DEFINED + live dispatch: yes; live
redefine of the same name + re-dispatch: yes. Exit 0.

## What the catalog learns

Answers #5's open question: the param-dropping in `guest-welcome-reword`
was habit, not a second kind-guard — given a goal whose new body MUST
use both params, the model used both, in a shape the catalog had never
seen (a `| ok q |>` chain). Second: bodies compose. The define contract
stores source and re-parses per dispatch, so a chained body was always
mechanically possible; this is the first live evidence a model will
produce one and that the whole loop — install, vocabulary listing,
dispatch, possession — carries it. Third: the same-kind rebinding rule
generalizes across kinds — append→append succeeds exactly as
speak→speak did, so the #4 refusal really was about cross-kind mixing,
not about `say`. The next replay should probe stacking: a defined verb
whose body calls an EARLIER invention (growth composing on growth), or
the self-reference edge — a redefine whose body calls its own name
(does the model try it, and does dispatch recurse into the new body?).
Verdict: full pass — done-gates met, first chained body in the shelf.

## Operator disclosure

Exactly one live session ran (koruc exit 0, ./a.out exit 0). No full50;
small spend (6 turns, max completion 2195). No secrets in either file
(grep-checked). headless/live.k goal edits stay uncommitted in the
worktree; main tree untouched except this catalog entry.
