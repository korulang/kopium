---
name: arbiters-reconcile
description: Reconcile a project's gardened ADD skills against the reference repo — a conversational 3-way merge that pulls upstream improvements WITHOUT clobbering local gardening. Use when the reference (`6digit-skills`) has evolved and a project that already has ADD installed wants to absorb the changes. This is the dedicated front door for what used to be buried in `arbiters-init`'s "upgrade mode" — invoke it directly instead of re-running the installer. Fire when the user says "reconcile ADD", "reconcile the arbiters skills", "pull upstream skill changes", "sync ADD here", "upgrade the ADD skills", or "the skill repo changed, update this project". NOT the daily run (`/arbiters`) and NOT first-time install (`arbiters-init`).
---

# Arbiters-reconcile — pull reference improvements, keep local gardening

The reference (`6digit-skills`) evolves; each project **owns its copy** of the ADD
skills and is *meant* to diverge (the Gardener tunes them to that project's
harness). So reconciliation is **not** a sync-to-identical — **single source of
truth is a NON-GOAL.** It is a conversational, opt-in 3-way merge: fold upstream
improvements in *around* the local gardening, never over it. You (Arbiter + human)
adjudicate; nothing applies without a nod.

This is the dedicated door for what was once `arbiters-init`'s "upgrade mode."
Reconciliation lived inside the *installer* — a skill nobody re-runs — so projects
drifted from the reference forever. Same lesson as the Gardener door: a good organ
with no front door never gets invoked. This *is* the front door.

## When to use
- **Reconcile (this skill)** — ADD is already installed here and the reference has
  changed. The common case.
- **Daily run** — `/arbiters`. Not this.
- **First install** — `arbiters-init`. Not this.

## 0 · Find the anchor
- Read `./.claude/.add/seed.json` → the `reference` repo path and the
  `reference_sha` last reconciled from.
- The 3-way anchor is `./.claude/.add/base/` — an exact snapshot of what was last
  seeded/reconciled. It is what lets you tell *"the Gardener tuned this locally"*
  apart from *"the reference changed upstream."*
- **No `.claude/.add/base/`?** This project predates anchored seeding. You cannot
  3-way. Fall back to a **2-way**: show the human each reference-vs-local
  difference and adjudicate by hand, treating *nothing* as automatically
  upstream-wins. Then write a fresh base snapshot (step 4) so next time is clean.

## 1 · Compute the three sides, per file
For each ADD skill file under `.claude/skills/arbiters/` (and the methodology doc
`.claude/ARBITER_DRIVEN_DEVELOPMENT.md`) — **and `SCENE.md` is excluded entirely;
see below** — hold three versions:

- **base** — `./.claude/.add/base/<f>` (the anchor)
- **local** — `./.claude/skills/.../<f>` (what this project runs now, possibly gardened)
- **reference** — `<reference>/skills/engineering/arbiters/<f>` (upstream now)

Then:
- `diff base local` → did the **Gardener** change it here?
- `diff base reference` → did the **reference** change upstream?

## 2 · Resolve each file
- **Reference changed, local unchanged** → **fast-forward**: copy reference → local.
- **Local changed, reference unchanged** → **leave it.** Gardening is sovereign.
- **Both changed** → the real work. Read all three, grasp the *intent* on each
  side, and propose a **merged** version that keeps the local tuning and folds in
  the upstream improvement. Show the human the conflict + your proposal; apply on
  their nod. **Semantic merge — you are an LLM, read for intent; do not diff3.**
- **New file upstream** (in reference, not in base/local) → propose **adding** it.
  (E.g. a new phase file like `challenge.md`.) Default yes, but show the human.
- **File gone upstream** (in base/local, not in reference) → propose **removing**
  it — unless it was locally gardened, in which case surface the tension and let
  the human decide (a removed-upstream file the project still depends on is a
  design question, not a delete).
- If the methodology doc changed *drastically*, discuss the shape with the human
  before merging file-by-file.

## 3 · SCENE.md is untouchable
`SCENE.md` is **born-original** — pure local sovereignty, authored from this
project's own first walk. There is no reference `SCENE.md`, ever. **Do not 3-way
it, do not diff it, do not propose a "merged" scene.** If the reconciliation
machinery so much as reaches for `SCENE.md`, that is the bug — skip it without a
second thought.

## 3b · Carry the visual-identity CONVENTION — never the face
The visual + sonic identity (`visual-identity.json` + `./visual/`) is the rendered
twin of `SCENE.md`, and it splits the same way — one rung down from the scene's
sovereignty:

- **The CONVENTION travels with the methodology.** A project that predates this
  primitive has no face yet. Reconcile **carries the convention in** by planting
  the derived baseline where it's missing:
  `node <reference>/scripts/plant-visual-identity.mjs .` — it writes
  `visual-identity.json` (palette + name-hash note) and seeds `./visual/` ONLY if
  absent. Do this once during reconcile so the repo joins the fleet's cockpit.
- **The FACE does NOT.** The manifest and the matter under `./visual/` are
  **forged per-repo** — a distinct accent, a hand-authored backdrop, a tuned note.
  Like `SCENE.md`, there is no reference face to merge *from*. **Do not 3-way it,
  do not diff it, do not "upgrade" it, do not re-derive over it.** The planter is
  idempotent and leaves any existing face untouched — lean on that; never reach
  past it. Only the *convention* (that a face exists, its schema) is shared.

## 4 · Re-snapshot the anchor
After the human has accepted the merges, **re-baseline** so the next reconcile has
a fresh anchor:
- Copy the reference's *current* arbiters files + methodology doc into
  `./.claude/.add/base/` (mirroring exactly what upstream now holds — including any
  new files added, minus any removed).
- Bump `reference_sha` in `./.claude/.add/seed.json` to the reference's current
  short SHA (`git -C <reference> rev-parse --short HEAD`).
- The base never contains a `SCENE.md` — there is nothing to snapshot.

## 5 · Optional harvest — back-port candidates (never automatic)
Reconciliation is pull-primary (reference → project), but a project's gardening is
sometimes the improvement the *reference* should have. While you have all three
versions in hand, **surface** any local change that looks worth back-porting
upstream as a conversational candidate — "this tuning in `<f>` might belong in the
reference." Never apply it upstream yourself; the reference is a different repo with
its own walk. Surfacing is the job; the human carries it across.

## Never
- **Clobber a gardened file** to make it match the reference. 3-way and adjudicate.
- **Touch `SCENE.md`** in any way. It is excluded entirely.
- **Reconcile a `visual-identity.json` or the `./visual/` matter.** Carry the
  *convention* (plant the baseline where absent); never merge or overwrite a face
  that exists — it is forged per-repo, like the scene.
- **Auto-apply** a merge the human hasn't seen and nodded to.
- **Reconcile just to reconcile.** Divergence is the goal, not a defect; pull what
  *improves* this project, leave what serves only uniformity.
- **Forget to re-snapshot the base** — an un-bumped anchor makes the next reconcile
  read stale, treating already-pulled upstream changes as new again.
