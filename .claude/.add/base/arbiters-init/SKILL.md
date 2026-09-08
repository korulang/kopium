---
name: arbiters-init
description: Install Arbiter-Driven Development (ADD) into a project — new or existing. One-time bootstrap, NOT the daily run (that's `/arbiters`). Seeds the project with its own copy of the ADD skills, plants the project's `SCENE.md`, probes the toolchain, grills the developer for a baseline, and writes a project-local orientation map. Fire when the user says "set up arbiters here", "install ADD in this project", "bootstrap arbiter-driven development", "onboard this repo", or wants to start using the methodology in a project that doesn't have it yet.
---

# Arbiters-init — bootstrap ADD into a project

One-time setup. After this, the daily driver is `/arbiters`. The full method:
`ARBITER_DRIVEN_DEVELOPMENT.md` in the `6digit-skills` reference.

This is **PLANT** in the plant / walk / tend trinity. The three skills are one
continuous figure — a garden:

- **arbiters-init** = **plant** the garden — author `SCENE.md`: the first walk,
  the ideal user, the feeling.
- **`/arbiters`** = **walk** the garden — read the scene, slice the gap.
- **Gardener** = **tend** the garden — prune what fights the scene, build the
  pit-of-success walls that keep the beds growing on their own.

You plant once. The walking and the tending go on forever after.

**Guiding principle — single source of truth is a NON-GOAL.** You seed the
project with its *own copies* of the ADD skills. They are meant to **diverge**:
the Gardener tunes them to *this* project's harness as the process evolves.
Don't try to keep them synced with the reference — copy-in, then let them drift.
That divergence is what lets the Gardener garden.

## 0 · Detect the mode
- **Fresh install** — no `.claude/skills/arbiters/` here → run steps 1–7.
- **Already installed** — it exists → do NOT re-seed (that clobbers gardening).
  **Use the `arbiters-reconcile` skill instead** — that is the dedicated front door
  for pulling reference improvements into a gardened project via a conversational
  3-way merge. `arbiters-init` is for *planting*, not *reconciling*.

## 1 · Seed the skills + install the membrane gate (copy, never symlink)
- Locate the reference repo (this skill is installed from it): `readlink -f ~/.claude/skills/arbiters-init` → walk to its repo root, or `~/src/6digit-skills`.
- Run `<reference-repo>/scripts/seed-into.sh <this-project>`. It copies the runtime ADD skills + the methodology doc into `./.claude/skills/` and `./.claude/`, and **installs the membrane gate** (`commit-msg` + `post-commit`) into the repo. The project now **owns** these copies.
- Confirm it printed `installed membrane gate`. **The gate is not optional — it is what makes a repo well-formed for ADD** (see the box below). A `WARNING: membrane gate NOT installed` line means the repo is not yet well-formed; fixing that is the first plant action, not a deferral.

> **Well-formed repo = the membrane gate is installed and firing.** The gate forces
> the two questions on every commit — "did a belief change?" (World Model) and "did
> a durable belief change worth gardening?" (Membrane) — rejecting silence. This is
> the canonical **pit-of-success wall** the Gardener exists to build: gardening that
> isn't forced by the commit is gardening that never happens. Well-formedness is
> measured by the *presence of the firing gate*, **never** by corpus size — a
> brand-new repo with an empty `concepts/` is fully well-formed. Full spec: the
> `membrane` skill's "The enforcement hook — the UNIVERSAL gate" section.

## 2 · Probe the toolchain (grounded)
- Discover, from the actual repo, how this project is built/tested/run/linted: the commands, the language/framework, entry points, where tests live, CI. Cite real files/commands — don't guess. (Spawn a read-only subagent if the repo is large.)
- This is the **existing scene** read live (tenet 3). It is the fast clock — measured from the actual repo, never from memory. Keep it terse; the orientation skill in step 5 is where it lands.

## Intake — the scene condenses from the membrane; it is never interviewed out of the human

The single load-bearing rule, and the reason the old "first-walk interview" is gone:
**`SCENE.md` cannot be generated from a blank page. It is the *residue* of the
membrane corpus** — the north star you can only see once a little history has
accumulated in `concepts/`. A brand-new repo has no such history yet, so on a fresh
install **you do not author a scene by interrogation.** You establish the factual
baseline (step 3), plant at most a thin honest *seed*, and let the real scene
condense later as the membrane fills — tended by the Gardener, read back out of the
corpus, never grilled into existence.

**This kills the register break on purpose. Never dip out of conversation into
"answer these three questions."** Dropping from a walk into a bulleted interview is
the fastest way to kill the very thing you're trying to capture — the feeling does
not survive the form. Whatever north star, feeling, or ideal-user exists surfaces
*in the flow of building and talking*, gets encoded into the membrane like any other
belief, and the scene reads out of that. The only difference between a greenfield
repo and a long-marinated one is **how much corpus already exists** — more history,
more scene to condense; none yet, a thinner seed. Same telos, one mechanism. (For a
marinated project the developer can brain-dump the vision freely — rambling,
unordered — and you, the evolver, distill it into membrane fragments with the
`membrane` skill; the scene then condenses from *that*. Never demand structure on
the way in — structure is the grill trap in disguise.)

## 3 · Establish the factual baseline (conversationally — never a checklist)
There are a few facts the repo can't tell you and you genuinely need. Get them **in
conversation**, folded into the walk — ask only the gaps the probe (step 2) didn't
already answer, never as a rigid Q&A:
- what this project *is*, in a sentence, and the current goal;
- the harness — the exact build / test / run commands actually used;
- the **source of truth** (tests? docs? a brain/ctx? a spec) — and which wins when two disagree;
- what's **off-limits** — what would make the developer angry if an agent did it;
- where conventions live (a CLAUDE.md, a docs dir, nowhere yet).

These are factual and fast. They feed the orientation skill (step 5), **not** the
scene. Do not try to grill a *feeling* out of anyone — the feeling is not a fact and
does not come from questions.

## 4 · Plant `SCENE.md` — condense it, don't author it
`SCENE.md` is the felt north star, and it **condenses from the membrane** (see Intake
above) — you never blueprint it and you never interview for it. On a fresh install the
corpus is thin, so this step is deliberately light:

- If the conversation has already surfaced an obvious north-star line — the one
  sentence the whole project points at — write it as a **seed** and say plainly it's
  a seed.
- If it hasn't, write the thinnest honest stub — *"no scene yet — condenses from the
  membrane as the corpus grows"* — and move on. **Init must not block on a scene.**

The scene gets walked and tended into shape later, once `concepts/` holds a little
history; the Gardener reads it back out of the corpus. What matters now is only that
the file exists, is honest, and points at the membrane as its source — not that it's
complete.

Write it to `./SCENE.md` at the **repo root** (NOT inside `.claude/` — the scene is a
vision the human should see in plain sight, not buried in a tooling dotdir). It is
project-local, project-owned, travels with the repo — one north star with possibly
**many named beds** (sub-scenes a later session can pick which to walk). The
container, as the corpus fills it in:

- **north star** — the one line the whole project points at;
- **ideal user(s)** — the one person it's for, drawn as a character a Scout can judge a slice against (the transmissible anchor that crosses the sealed shell — a scout gets *this person*, never the scene file). It too condenses from the corpus, not from a grill question;
- **loose directions** — beds, not blueprints;
- **what it says no to** — the foreign philosophies the scene rejects on sight;
- **a light tending log** — last-mutated, by which loop, so the slow clock is visible (tenet 4 applied to the scene itself).

Header discipline the file must announce to every cold reader: **read-many, write-rarely; two clocks — the scene is slow and sticky, the existing scene is fast and live; scouts get the ideal-user, NEVER this file; the scene condenses from the membrane.** Reading `SCENE.md` is not reading a doc *about* the garden — it *is* stepping into the garden. It **subsumes** any old scattered "north star" pointer — fold those in, then let the orientation skill (step 5) stay terse as the existing-scene instrument.

> **`SCENE.md` is BORN-ORIGINAL.** It is unique per project, condensed from this project's own membrane. It is **never copied from a reference and never reconciled against a template — there is no reference `SCENE.md`, ever.** This is pure local sovereignty: a project's soul is not a thing you merge. See the loud exclusion in **Upgrade mode** — an upgrade pass must never reach for `SCENE.md`.

### 4b · The rendered twin — `visual-identity.json` (planted mechanically in step 1)
Every repo declares its own **face**: a visual + sonic identity, the *rendered twin* of `SCENE.md`. Where the scene is the felt vision, the face is how a cockpit surface (the War Room) shows this repo's data in its own light — so a parallel fleet is told apart at a glance. Unlike the scene, this is **not** authored conversationally: its baseline is **cheap-derived**, so `seed-into.sh` (step 1) plants it mechanically. You don't walk it; it is already correct the instant it lands. Full doctrine lives next to the scene's, in `scene.md` ("The rendered twin").

- **The artifact:** `visual-identity.json` at the **repo root**, next to `SCENE.md`, PLUS committed assets under `./visual/`. The JSON is the manifest (values + pointers); the PNGs are the matter — a `git clone` brings the whole face.
- **The schema:** `{ name, palette: { base, text, surface, accent } (hex), background: { image, depth, parallax } | null, sound }`. The derived baseline fills `palette` from Catppuccin Mocha (base/text/surface grounded in `6digit/src/mainview/app.css`) with a **per-repo `accent`** name-hashed over the accent ramp, and a **per-repo `sound`** — a piano note chosen by the SAME djb2 hash and 7-note vocabulary the studio audio-engine (`6digit-studio/src/lib/audio-engine.ts`, `playPianoNote`) plays. Same repo ⇒ same colour, same key, forever. `background` starts `null` — an honest stub, not a dangling pointer.
- **THE SPLIT — say it out loud:** the **manifest + convention travel with the methodology**; the **matter (the art under `./visual/`, and any hand-forged override) is forged per-repo and does NOT propagate.** This is the same sovereignty line as `SCENE.md`, one rung down: the contract is shared, the face is local.
- **Never clobber.** The planter is idempotent — if a `visual-identity.json` already exists it is left untouched (it may be forged). Init only plants where none exists.

## 5 · Write the project orientation skill (a MAP, never a copy)
- Synthesize the probe + grill into `./.claude/skills/<project>-toolchain/SKILL.md` — the `koru-toolchain` analog for this project. This is the **existing-scene instrument**.
- It **points** to the right tools and info sources (run `X` to build, tests live in `Y`, source of truth is `Z`); it does NOT duplicate their contents. Terse. This is what every `/arbiters` Scout and Contestant reads first.
- It is the complement of `SCENE.md`, not a rival: the orientation skill is the *existing* scene read live (fast clock, where you are); `SCENE.md` is the *ideal* scene (slow clock, where you're going). Keep them in their lanes.
- **Record the canonical standard** — the rulebook / invariants that say what's *legal* in this project (the source-of-truth answer from the grill; e.g. a `CLAUDE.md` + `AGENTS.md`, or "the passing tests"). Name it as a must-read for every subagent, because it's what `/arbiters` step 2.5 discriminates a seam's premise against. A project with no written standard is itself a finding — say so.
- Name the few "things that will bite you" — the misconceptions specific to this project that cost an agent hours.

## 6 · Charter + chronicle (optional)
- If the human wants it: write a short **charter** (what this project is, the bar for "done", what's worth a chronicle beat) and arm `prose-chronicle`.

## 7 · Verify + hand off
- Confirm `/arbiters` can run here: skills present in `.claude/skills/`, `SCENE.md` planted, the orientation skill written, the methodology doc readable.
- Confirm the repo is **well-formed**: the membrane gate is installed and fires — `.git/hooks/commit-msg` exists, and the gate's own test harness is green: `node .claude/skills/membrane/hooks/test/hook-test.mjs .git/hooks/commit-msg.cjs`. A repo without a firing gate is not well-formed for ADD.
- Tell the human to **commit the seeded `.claude/` into the project** (the methodology — and the garden — now travel with the repo) and to start a fresh session so the new skills register.
- Leave the first baton: `↪ HANDOFF: ADD installed in <project>; scene planted, baseline established · next: /arbiters · or pivot (Muse).`

## Upgrade / reconcile — moved to its own skill
Pulling reference improvements into an already-installed project is **no longer
done by re-running `arbiters-init`.** It has its own front door: the
**`arbiters-reconcile`** skill — a conversational 3-way merge (base snapshot vs.
local gardening vs. upstream reference) that keeps local tuning and folds in
upstream changes, with `SCENE.md` excluded entirely. Init *plants*; reconcile
*reconciles*. Point the human there: "to upgrade, run `arbiters-reconcile`."

(The 3-way anchor reconcile depends on — `.claude/.add/base/` + `.claude/.add/seed.json` —
is written by `seed.json`/`seed-into.sh` at plant time, here. Reconcile re-snapshots
it each run.)

## Never
- Symlink the skills in (defeats the copy-in / let-it-diverge principle).
- Clobber a gardened skill on upgrade — 3-way merge and adjudicate instead.
- Copy a `SCENE.md` from anywhere, or reconcile a project's scene against a template — it is born-original, condensed from this project's own membrane.
- Clobber an existing `visual-identity.json` or the `./visual/` matter — the manifest baseline is derived and planted only where absent; the art is forged per-repo and never propagates.
- Block init on a complete scene — a thin honest stub is correct; the scene condenses from the membrane as the corpus grows.
- Break conversational register to author the scene — no "answer these three questions" interview. The scene condenses from the membrane; the feeling does not survive the form.
- Duplicate tool docs into the orientation skill — point to them.
- Grill the human for things the repo already answers — probe first, ask only the gaps.
