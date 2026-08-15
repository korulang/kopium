# KOPIUM — an agent whose only tool is a Koru interpreter

The governing design is **[`KOPIUM_RUNTIME.md`](KOPIUM_RUNTIME.md)** — read it
first. This repo is the implementation of that stance: a vocabulary-parametric
agent bridge. Hand the runtime a `register` block and it *becomes* an
interpreter for that world — wire grammar, prompt, enforcement, and growth
mechanism all derived from the declaration.

## Layout

- **`wired/`** — the wired client: vaxis chrome, curl multi + SSE, a real model
  streaming into a store-held transcript. It has a network; the tool surface is
  being pulled in from the headless side.
- **`headless/`** — the headless agent: the network taken out, one tool put in.
  The model emits an invocation per turn; `std/bridge:run` dispatches it under
  the `notes` scope's possession rules. README inside explains the four
  demonstrations.
- **`wired/holes/`** — compiler/toolchain gaps kopium tripped, each with a
  repro. When one closes, the pin moves into the koru regression suite and the
  HOLE.md records the verdict.

## The one law

**The koru compiler is the product. When you hit a compiler / toolchain /
codegen gap here: FIX THE TOOLCHAIN. NEVER route around it in the app.** A
green app earned by dodging the gap is a lie about the toolchain the app exists
to exercise. Suspected gap → assume ~50% chance it's your own misunderstanding,
float it, fix in `/Users/larsde/src/koru` with the regression pinned first.

## Building

Requires a `koruc` from `/Users/larsde/src/koru` main (`zig build` → `zig-out/bin/koruc`,
symlinked to `koruc` on PATH) and the koru-libs checkout at
`/Users/larsde/src/koru-libs` (the relative paths in each `koru.json` assume
this layout).

```
cd headless && koruc session.k && ./a.out    # canned model, the bridge demo
cd headless && koruc live.k && ./a.out       # real model over OpenRouter
cd wired && koruc d_turns.k && ./a.out       # the terminal agent
```