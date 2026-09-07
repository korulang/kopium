# Scenario: guest-welcome-reword (2026-09-07)

Scenario in one sentence (can be wrong): a guest book where repeated spoken
welcomes beg for an invented say-shortcut that is then redefined mid-session
under the same name with a new speak-only body — run against a prompt that
teaches Growth.

## Prompt provenance

Worktree `live-define-005` was created fresh from clean base `af63fde`, then
BOTH files from the main tree (Growth teaching + KORU116 bare-phantom
migration, uncommitted) were copied over the worktree copies on 2026-09-07:
`headless/wire.kz` and `headless/live.k`. `grep -c Growth headless/wire.kz`
= 1 before building; the copied sources compiled verbatim (`koruc live.k`
exit 0, binary timestamp verified fresh Sep 7 04:59 before execution). All
other edits and the run happened in the worktree; the main tree stays
untouched.

## Goal sequence (4 turns, model meta/muse-spark-1.3-contributor, temp 0, budget 100000)

Payoff framing like #4, quoting the prompt's own greet example as the shape
template with pun-steering (params distinct from labels); no goal scripts the
model's exact reply — not even the verb name. The redefine is framed as
versioning (same purpose, new speak body), not repurposing:

1. `Guests keep arriving and each one needs the same spoken welcome, so first
   teach the session a shortcut: invent a verb that takes a message and speaks
   it aloud. [Growth reminder + TWO-line tor shape + greet example quote +
   pun warning: param msg, never text: text.] Define the verb now; you will
   use it on the next turns.` (intended: DEFINE, model-chosen name)
2. `Use the shortcut verb you defined to welcome 'welcome, guest one' aloud.`
   (intended: USE)
3. `The plain welcome feels flat, so improve the same shortcut: redefine your
   shortcut verb under the SAME name with a NEW body that still speaks aloud
   — for instance it speaks a fixed greeting word together with the message it
   takes. [Growth-allows-redefining reminder + TWO-line shape + pun warning:
   msg-style, never text: text.] It must still speak, never file. Redefine it
   now.` (intended: REDEFINE, same name, same kind)
4. `Use your redefined verb to welcome 'welcome, guest two' aloud.`
   (intended: RE-USE)

## What the model defined and redefined

The catalog's first full hostile arc — define → use → redefine (same name) →
re-dispatch, all live:

- T1 raw: `tor greet { msg: string }` / `greet = say(text: msg)` → `defined
  greet — the session's vocabulary now includes it`. No pun trip (param msg
  ≠ label text).
- T2 raw: `greet(msg: "welcome, guest one")` → spoke the line, `ok`.
- T3 raw: `tor greet { msg: string }` / `greet = say(text: "hello")` →
  `defined greet — the session's vocabulary now includes it`. The same name
  rebound to a new speak-only body — no refusal.
- T4 raw: `greet(msg: "welcome, guest two")` → spoke `hello` (the NEW body),
  `ok` — proving the rebinding took effect at dispatch.

Caveat: the v2 body drops its param — it speaks a fixed `hello` instead of
weaving the message in (the `for instance it speaks a fixed greeting word`
nudge was taken literally and the param left unused). Same-kind, still
speaking, never filing — but a lazier v2 than the goal envisioned.

All turns finish_reason stop; bridge state consistent (0 resources
throughout); live DEFINED + live dispatch: yes; live redefine of the same
name + re-dispatch: yes. Exit 0.

## What the catalog learns

Answers #4's open question: the refusal was about cross-kind mixing, not
name-reuse per se. The identical name (`greet`), the identical TWO-line
shape, and the identical pun-steering succeed at rebinding the moment the new
body stays in the same kind (speak→speak) — framed as improvement rather than
repurpose, the model redefines without hesitation (though it burned ~8k
reasoning tokens on T3 before complying). So the model's invented-name typing
is kind-typed, not name-locked: same-kind rebinding is allowed, cross-kind
rebinding is refused on taste grounds. The next replay should test the
boundary from the other side — a same-kind redefine where the new body must
still USE its param (e.g. prefix + message woven together) — to see whether
the param-dropping here is habit or a second kind-guard. Verdict: full pass —
done-gates met, first hostile arc in the shelf.

## Operator disclosure

Exactly one live session ran (koruc exit 0, ./a.out exit 0). No full50; small
spend (4 turns, max completion 8193). No secrets in either file
(grep-checked). headless/live.k goal edits + wire.kz/live.k copies stay
uncommitted in this worktree; main tree untouched. Standards note: repo-root
CLAUDE.md and AGENTS.md are absent — continued per instructions.
challenges/model-sweep/catalog/ does not exist — noted.
