# SCENE.md — the garden made into a file

This is not a phase of the run; it is the doctrine of the artifact every phase
leans on. `walk.md` opens it on the way in, `muse.md` is the one phase allowed to
argue it should change, `gardener.md` reshapes its beds, and `arbiters-init`
plants it. So `scene.md` describes the *thing*, not a step: what `SCENE.md` is,
where it lives, what goes in it, and the disciplines a cold reader must obey the
moment they hold it.

## What it is — reading it *is* stepping into the garden

`SCENE.md` is the garden made into a felt, hand-walkable file. It is **not a doc
*about* the garden** — there is no separation between the description and the
thing described. You don't read a blueprint and then go imagine the space;
opening the file *is* the walk into the ideal scene. That is why the garden is
the right figure and "a finished house" is the wrong one: a garden is never
finished. It is felt, not specified — alive, tended, a little different every
season. `SCENE.md` holds that "well-architected but still fluid" stance in
prose, which is why it reads as something you walk rather than a spec you
satisfy.

The operational consequence — the reason this is doctrine and not decoration:
because the scene is *felt*, it can only be held in the conversation. Every scout
that reads it secondhand, every contestant that builds against it, gets a lossy
distillation of the feeling, never the file. The file stays with the walkers.
Hold that as you read everything below.

## Where it lives — `SCENE.md` at the repo root, project-owned

The file lives at the **repo root** as `SCENE.md` — not tucked inside `.claude/`.
It is a felt, hand-walkable vision the human should *see*, so it sits in plain
sight at the top of the tree, not buried in a tooling dotdir. It is
**project-local, project-owned, and
travels with the repo** — committed, versioned, moving with the checkout the way
the code does. Each project has its own garden. There is no shared scene, no
central registry of scenes, no template instance the project is a copy of. A
project's ideal is its own, and it sits inside the project so the walk always has
it within reach.

## What goes in it — the container

Before the list, the guard that travels with it: these are what a scene **can
grow to hold over time** — never a template to fill in one sitting, and never a
list of questions to grill the human through. The co-derivation rule below is
binding from the scene's first line.

And the deeper guard, on where the scene comes from: **the scene condenses from
the membrane — it cannot be generated from a blank page.** It is the *residue* of
the concept corpus, the north star you can only see once a little history has
accumulated in `concepts/`. So a fresh repo does not get a scene interviewed out
of the human; it gets a thin honest seed, and the real scene condenses later as
the membrane fills, read back out of the corpus by the Gardener. This is why the
grill-checklist is banned twice over: not only does the feeling not survive the
form, there is nothing to distill yet on day one.

`SCENE.md` holds, in felt prose rather than a schema:

- **North star** — the one direction the whole project bends toward.
- **Ideal user(s)** — the person (or few people) the work is *for*. This is the
  transmissible anchor (tenet 2): the part of the scene that can cross the sealed
  shell to a subagent. You don't hand a scout the file; you hand it the ideal
  user.
- **The feeling** — the texture of the ideal scene, the thing that tells you "this
  fits" or "this fights" when a slice lands back on the walk. This is what a
  schema can never capture and why the file is prose.
- **Loose directions** — not a roadmap, not a backlog; the shape of where the
  garden is growing, named loosely enough that the work can still surprise you.
- **What it says no to** — the explicit refusals. The scene is at least as much
  defined by what it rejects as by what it reaches for: a `Result` type, a
  happy-path branch — implementable, reasonable, and a direct contradiction of
  "branches are equal, no happy path." Writing the no's down is what lets the
  pull-feedback valve (tenet 7) catch a well-meaning item that fits the code but
  fights the scene.
- **A light tending log** — last-mutated, by which loop. Just enough that the
  slow clock is *visible*: who reshaped the beds, and when. This is tenet 4
  (low friction, high transparency) applied to the scene itself — the scene's own
  drift must never be invisible state.

## One garden, many beds

A scene is **one garden with many beds.** The north star is the garden; under it
sit named beds — sub-scenes, distinct stretches of the ideal that each have their
own feeling. A session does not walk the whole garden every time; it **picks
which bed it is walking** and names that bed out loud on the walk (`walk.md`,
move 3). The bed scopes the day: the gap you slice, the lens you scout, the
feeling you judge against are all the *bed's*, not the garden's at large. This is
how one scene serves a project broad enough to have several ideals running at
once without flattening them into a single average.

## Header discipline — what a cold reader must obey

A reader who opens `SCENE.md` cold must obey two rules before doing anything with
it. Put them at the top of every scene so they are unmissable:

- **Read-many, write-rarely.** You read the scene on every walk; you almost never
  edit it. The existing scene moves fast and lives; the ideal scene is slow and
  sticky. Mutating it is a deliberate, rare, walk-level act — never a mid-session
  convenience.
- **Scouts get the ideal user, NEVER this file.** The scene does not cross the
  sealed shell. A subagent is served the *ideal user* — the felt anchor distilled
  to something a sealed shell can act on (tenet 2) — and never the file itself.
  Handing a scout `SCENE.md` would pour the wander into a cold shell that has no
  altitude to use it, and it would make the methodology recursive when it is
  non-recursive by construction. The file stays with the walkers.

## Two clocks

The scene runs on a different clock from the repo, and conflating them is the
classic instrument-corruption error (tenet 3). The **existing scene** — what the
code actually is — is fast and live, re-read from the actual repo every session,
never from memory and never from the scene's own description of itself. The
**ideal scene** — `SCENE.md` — is slow and sticky, mutated rarely and
deliberately. You measure where you are against the repo, fresh, every time; you
measure where you're going against the scene, which barely moves. The gap between
the two, bed by bed, is the work (tenet 1). Reading the slow clock as if it were
the fast one — trusting the scene's self-description as the live state — is how
the instrument lies.

## It subsumes the old north-star pointer

`SCENE.md` **subsumes and upgrades the old scattered "north star" pointer.**
Where a project once kept a thin line in an orientation map pointing at its
direction, the scene now holds the whole felt ideal — north star, ideal user,
feeling, refusals, and all. The division of labour is clean: the
toolchain/orientation skill stays terse and is the **existing-scene
instrument** (the fast clock, the live read of the repo); `SCENE.md` is the
**ideal** (the slow clock). Don't duplicate orientation mechanics into the scene,
and don't let the scene rot into a second backlog — it holds the ideal, the
instrument holds the measurement.

## Born-original — excluded from the upgrade merge entirely

The scene is **born-original**: authored unique per project, never copied from a
reference and never reconciled against a template. There is no reference
`SCENE.md`, ever — not a canonical one to fork, not a golden one to diff against.
Each garden is grown from its own project's soil.

This has a hard operational consequence for `arbiters-init`'s upgrade mode. When
init re-runs on a project that already has ADD installed, it performs a 3-way
merge to pull in skill improvements without clobbering local edits. **`SCENE.md`
is excluded from that merge entirely.** It is pure local sovereignty: there is no
upstream version to merge *from*, so there is nothing to reconcile. Init may
*plant* a scene where none exists, but it never reconciles, overwrites, or
"upgrades" an existing one. The garden belongs to the project, and the upgrade
machinery does not reach into it.

## The scene is co-derived, never authored-and-presented

The scene is **felt into being with the human, one line at a time** — it is not a
document the agent writes alone and hands over for a signature. This is the spine's
top rule ("Conversational, first and foremost") applied to the artifact: the most
seductive way to corrupt a scene is for the agent to read the design docs,
synthesize a complete felt scene — north star, ideal users, feeling, beds, the
no-list — and present it for the human to approve. That is **author-and-present**,
and it produces a scene the human *ratified* but never *committed to* — a feeling
no one actually holds, which is precisely the corrupted instrument the next reader
builds against.

So when a scene is born or grows: bring **one** proposal — a single line, in the
human's own words wherever you have them — and stop. Let the next line come from
what the human says back. The scene that ends up in the file is the residue of
that exchange, small and true, never a wall the agent generated and the human
waved through. Keep it small on purpose: an overarching vision the human can hold
in their head beats a sprawling container they skimmed and approved. The sections
above describe what a scene *can* hold over time — not a template to fill in one
sitting.

## A thin honest stub beats a faked-complete scene

A scene does not have to arrive whole. **A thin, honest stub — "no north star yet;
here is the seed" — beats a faked-complete scene every time.** A scene padded out
to look finished is worse than a one-line seed, because a cold reader trusts the
file as the ideal and builds against a feeling no one actually committed to. The
seed tells the truth: the garden is young, and growing it is itself a candidate
for a Muse day.

So **init must not block on a complete scene.** Plant the seed, mark it honestly,
and let the walks grow it. A scene that says "I am only a seed" is a working
scene; a scene that pretends to a north star the project hasn't found is a
corrupted instrument from its first read.

## The rendered twin — `visual-identity.json`

`SCENE.md` is the *felt* vision. Its **rendered twin** is the repo's **face**: a
visual + sonic identity a repo declares about itself, committed and repo-local, so
a cockpit surface (the War Room) can show each repo's data in its own light and a
parallel fleet is disambiguated at a glance. The scene is what the project *means*;
the face is how it *looks and sounds* while you work it. Twins, not rivals — one
walked, one rendered.

### Where it lives — the manifest at the root, the matter beside it

- **`visual-identity.json`** at the **repo root**, next to `SCENE.md`. It is the
  *manifest*: the values and the pointers.
- **`./visual/`** holds the *matter* — the committed PNGs. A `git clone` brings the
  whole face because the matter travels in-repo, not in some central registry.

### What it holds — the schema

```json
{
  "name": "<repo>",
  "palette": { "base": "#11111b", "text": "#cdd6f4", "surface": "#313244", "accent": "#cba6f7" },
  "background": { "image": "./visual/background.png", "depth": "./visual/background_depth.png", "parallax": 0.15 },
  "sound": "E"
}
```

- **palette** — hex. The derived baseline is Catppuccin Mocha (base/text/surface
  grounded in a real baked palette, `6digit/src/mainview/app.css`) with a **per-repo
  `accent`** — the signature colour, name-hashed over the accent ramp so each repo
  reads distinct against a shared dark base.
- **background** — the albedo (`image`) + `depth` map + `parallax` strength. This is
  the same depth-parallax pattern 6digit-cordial renders (picture + depth, offset by
  depth in the shader). It is `null` until the art is forged — an honest stub, never
  a dangling pointer.
- **sound** — a musical note (A–G). Chosen by the SAME djb2 hash and 7-note piano
  vocabulary the studio audio-engine (`6digit-studio/src/lib/audio-engine.ts`,
  `playPianoNote`) plays, with the hash input generalized to the **repo** — so each
  repo rings in its own key and the engine plays the note the repo declares. The
  engine is referenced, never reinvented: the repo owns the static value, the engine
  stays the single player.

### The split — manifest travels, matter is forged local

This is the scene's born-original sovereignty, one rung down:

- **The manifest + the convention travel with the methodology.** Its baseline is
  **cheap-derived** — palette + name-hash note — so `arbiters-init` plants it
  **mechanically** (via `seed-into.sh`; unlike the scene, you do not walk it into
  being), and `arbiters-reconcile` **carries the convention** into a repo that
  predates it by planting the baseline where absent.
- **The matter does NOT travel.** The art under `./visual/`, and any hand-forged
  palette or note that overrides the baseline, is **forged per-repo** and never
  propagates. There is no reference face to merge from — the same reason `SCENE.md`
  is excluded from every reconcile. The planter is idempotent and **never clobbers**
  an existing face; only the *convention* is shared.

The felt scene is authored conversationally and born-original; the face is derived
and mechanical at baseline, then forged local. Both are project-owned, both travel
with the repo, and neither is ever reconciled against a template.
