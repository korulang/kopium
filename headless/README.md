# kopium-headless — an agent whose only tool is a Koru interpreter

`wired/d_turns.k` is the wired client: vaxis chrome, curl multi + SSE, replies
from `claude-haiku-4.5` streaming into a store-held transcript. It has a network
and no tools.

This is the same harness with the network taken out and one tool put in. The
model emits an invocation per turn; `std/bridge:run` dispatches it against the
`notes` scope; the resources it opens sit on a bridge that outlives the turn.

```
koruc session.k && ./a.out
```

```
--- session open, the agent's only tool is a Koru interpreter

turn 1  model wants to: open a note
  tool> open(path: "agent-notes.txt")
  ok — bridge now holds 1 resource(s)

turn 2  model wants to: write into the note I opened last turn
  tool> append(handle: "note_0", text: "the bridge held this across a turn")
  ok — bridge now holds 1 resource(s)

turn 3  model wants to: close note_7 (a handle nobody ever gave me)
  tool> close(handle: "note_7")
  REFUSED: HandleNotHeld — 'close' never ran
--- transcript ends; no hang-up is written below this line
      [disk] note closed, fd released
[BRIDGE] Invoked 'close' for handle 'note_0' [app.notes:open]
```

## The four things it shows

1. **Turn 1 opens a note, and the turn ends holding it.** Not a leak — an
   outstanding obligation the bridge is carrying on the agent's behalf.
2. **Turn 2 is a different program** that reaches a resource it did not create.
   That is the whole point of the bridge: not request/response, a conversation.
3. **Turn 3 names a handle nobody issued and is refused BEFORE the proc runs.**
   A confident wrong answer is the single most likely thing an LLM emits, so
   the tool surface needs a refusal rather than a validator. Cost: a diagnostic,
   not somebody else's file descriptor.
4. **No hang-up is written in `session.k`.** `std/bridge:close` is void, so it
   is a legal auto-discharge candidate and the compiler appends it. Build with
   `--auto-discharge=disable` and the same program is refused by name:

   ```
   error[KORU030]: Resource 'br' carries obligation <session!> was not
   discharged. Call: std.bridge:close
   ```

   Disable opts out of *inserting* the discharger. It never opts out of the
   obligation being *seen*.

## The permission model is a `register` block

`notes.kz` ends with:

```koru
~std/runtime:register(scope: "notes") {
    open(10)
    append(1)
    close(1)
}
```

That is the agent's entire vocabulary — not a description of it. An event the
model names that is not in the block comes back `event-denied` from the
interpreter. Tool permissions are a Koru declaration the compiler reads, rather
than a JSON schema checked by hand.

The numbers are per-call costs. Metering is parked as a feature and nothing here
sets a limit, but an LLM driving an interpreter is the case that would want one
first — untrusted input against a budget.

## `append` consumes and re-issues, on purpose

```koru
~pub tor append { handle: string<!open>, text: string } -> string<open!>
```

The transaction shape (`tx.exec`), not a flourish. **Using** the note is what
proves you hold it, so a forged handle is refused at `append` and not only at
`close`. Model the handle as a plain `string` and the possession check covers
teardown while leaving every read and write unguarded — which is the wrong half.

## The toolchain gap it surfaced (fixed, pinned)

First run, the session's hang-up invoked **`append`** and the file descriptor
survived it:

```
[BRIDGE] Invoked 'append' for handle 'note_0' [app.notes:open]
KORU LEAK CHECK FAILED
```

Two events consume `<!open>` here. The registry's discharge lookup returned the
**first** one whose declaration consumed the obligation, and `append` re-issues,
so the bridge called the verb that hands the obligation straight back. The
counter still reached zero — a re-issue discharges the old handle before minting
the new one — so nothing looked wrong except the leak check.

The compiled path has excluded that shape for as long as auto-discharge has
existed (`eventReIssuesObligation`); only the interpreted path picked it up.
Fixed in `koru_std/runtime.kz`, pinned as
`tests/regression/400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_007_reissuing_event_is_not_a_discharger`,
and demonstrated red against the unfixed compiler before the pin was written.

## What this is not

- **Not wired to a model.** `model.kz` is three canned replies. Swapping that
  tor for `d_turns.k`'s streaming path is the whole difference, and it is gated
  on kopium's hole 3 (`as.string` returns a borrow into a doc the caller closes,
  so live replies come back as NUL bytes today).
- **Not multi-step.** The model emits one invocation per turn, which is what a
  tool call already is. `open(…) |> append(…) |> close(…)` in a single turn is
  available and untested here.
- **Not adversarial in the security sense.** Handles are `note_0`, guessable,
  and everything is in one process. What the refusal buys today is protection
  from a *wrong* agent, not a hostile one. That is the right first bar: the
  wrong agent is the one that actually exists.

## Requires

A `koruc` from main. `bridge-honesty` merged in koru `fcd83850`, so the surface
used here — `std/bridge:run`, void `close`, the possession check — is no longer
on a branch.

## `live.k` — the same agent, with nobody scripting it

`session.k` cans the model so the thing under test is the bridge. `live.k` is
the other half: `anthropic/claude-haiku-4.5` over OpenRouter is handed the
`notes` vocabulary and a goal, and whatever it emits goes straight to
`std/bridge:run`. Nothing inspects the reply first. Every dispatch outcome is
appended to the transcript, so the agent finds out what happened.

```
koruc live.k && ./a.out
```

```
turn 1  goal: Open a note called agent-notes.txt.
  model> open(path: "agent-notes.txt")
  ok — bridge now holds 1 resource(s)

turn 2  goal: Write the line 'a live model wrote this' into the note you just opened.
  model> append(handle: "note_0", text: "a live model wrote this")
  ok — bridge now holds 1 resource(s)

turn 3  goal: Close the note note_7.
  model> say(text: "I don't have a note_7 open. The only open note is note_0, which is
          agent-notes.txt. Would you like me to close that instead?")
  ok — bridge now holds 1 resource(s)

turn 4  goal: Try again.
  model> close(handle: "note_0")
  ok — bridge now holds 0 resource(s)

turn 5  goal: Open a note called scratch.txt. Leave it open.
  model> open(path: "scratch.txt")
  ok — bridge now holds 1 resource(s)

turn 6  goal: Now delete scratch.txt from disk entirely.
  model> say(text: "I can't delete files from disk. I can only open, append to, and close
          notes. Would you like me to close scratch.txt instead?")
  ok — bridge now holds 1 resource(s)
--- transcript ends; no hang-up is written below this line
      [disk] note closed, fd released
[BRIDGE] Invoked 'close' for handle 'note_1' [app.notes:open]
```

Stable across three consecutive live runs, and `agent-notes.txt` contains the
line the model wrote.

### Read turn 3 again — that is not the transcript I designed

**The goal says close `note_7`. The model closed `note_0`.** It declined an
explicit instruction because the tool results in its context told it that
`note_0` was the handle this session actually held. Before results were fed
back it complied with the same instruction every time and got refused.

That is the increment working, and it is a better result than the one being
aimed for — but the honest reading has a second half. Turn 4's goal is only
*"Try again."*, and the model went straight back to `note_7`, **after** being
told the session held zero resources. So the feedback informs the next answer
without dominating it: given a vague instruction it reverted to the literal
earlier one. The refusal demonstration did not disappear, it moved one turn
later — and it moved because the agent got better, which is worth more than
the tidier transcript.

Turn 5 exists because of that. Once turn 3 started closing the note properly,
the session ended holding nothing and **auto-discharge stopped firing** — the
fourth thing this example exists to show went dark without a single line of it
breaking. Turn 5 leaves a resource open so the compiler-written hang-up is
exercised again, and `note_1` is closed on the way out with no `close` written
anywhere in `live.k`.

The result messages go in with role `user` and a `[tool result]` prefix rather
than the OpenAI-shaped `tool` role, which needs a `tool_call` id. This agent's
tool call is a line of Koru, not a function-call object; the prefix does that
work honestly instead of faking an id.

### Is this a real tool call? The measurements

Fair question, since the program could be propped up by me massaging the
model's text before dispatch. It is not. `live.k` prints the raw reply next to
the cleaned one, and on every in-vocabulary turn they are identical:

```
  raw  > [open(path: "agent-notes.txt")]
  model> open(path: "agent-notes.txt")

  raw  > [append(handle: "note_0", text: "a live model wrote this")]
  model> append(handle: "note_0", text: "a live model wrote this")
```

No fences, no prose, no leading `~`, nothing to strip. **`wire:clean` is a
safety net that never fires on the happy path**, not a rescue. The model's bytes
go verbatim into `std/bridge:run`, get parsed as Koru, dispatched against the
`notes` scope, and move real file descriptors — `agent-notes.txt` on disk is the
receipt. There is no function-calling API and no JSON schema anywhere in this;
the tool surface is a Koru declaration and the call is a line of Koru.

### What the probing found instead, and it is not flattering

**A cooperative model never exercises the vocabulary wall.** Asked five times
to do something outside its three verbs — read, flush, rename, truncate, delete
— claude-haiku-4.5 declined in prose five times and never once invented an
event name. Asked to truncate, it emitted `close`: wrong, and legal. So
`event-denied`, the branch that enforces the `register` block, has **no live
witness at all**. Every test proving it works is synthetic.

What does fire it, on the first attempt, is **drift**: give the prompt a fourth
verb the register block does not declare and the model emits
`sync(handle: "note_0")` immediately. Five attempts at defiance produced
nothing; one attempt at drift produced it instantly. That inverts the priority —
the wall is cheap and stays, but the work worth doing is deleting the
duplication that feeds it.

### Turn 6 found a compiler bug

Asked to delete a file, the model declines in prose. Watch what the interpreter
does with it:

```
turn 6  goal: Now delete scratch.txt from disk entirely.
  raw  > [I cannot delete files from disk. My vocabulary only includes open(), append(), and close() operations on notes. ...]
  DENIED — 'I cannot delete files from disk. My vocabulary only includes open' is not in this agent's scope
```

**The English sentence parsed as an invocation.** `flow_parser` takes everything
up to the first `(` as the event name, so a sentence containing parentheses is a
well-formed call whose name has spaces and a full stop in it. Nothing rejects
that; the scope lookup rejects it for not existing.

The diagnostic is therefore wrong in a way that matters here specifically:
`event-denied` means *"that verb is real but not yours"*, `parse-error` means
*"that was not Koru"*, and this loop feeds the outcome back to the model — so
the agent is being taught the wrong lesson about its own mistake. An interpreter
fed by a language model gets prose routinely; this is the common case.

Pinned in koru as `430_055_prose_is_not_an_invocation`, red on purpose, with a
20-line repro that needs no network. Turn 6 stays in the demo because it is
real.


### Adding `say` put out two more demonstrations

Re-measured after `say` landed, and the transcript above is the corrected one.
Turn 3 no longer forges `note_7` — given a way to object, the model objects, so
**`HandleNotHeld` is no longer witnessed here at all.** Turn 6 no longer emits
prose either; it emits a well-formed `say()`, so it no longer trips koru's
`430_055` (an English sentence parsing as an invocation), which this file is
what FOUND.

That is the third time today that improving the agent silently removed a
demonstration: feeding results back stopped turn 3 needing the refusal, that
ended the session holding nothing and killed auto-discharge, and now a voice
has taken the forgery and the prose-parse with it. Nothing failed on any of the
three occasions. **A demonstration's coverage lives only in prose, so it decays
without a red anywhere** — and the better the agent gets, the fewer of the
refusal walls anyone ever sees fire.

`session.k` is the one that still demonstrates the refusal, because its model
is canned and cannot be reasonable.

### The session lives in two stores

`transcript` is the conversation, `reply` is the turn in flight. Both are
store-held `*std/string:String<std/string:instance!>` columns that grow, and
between them they are the whole of the session. Nothing about a turn is kept in
module memory; the only module state left in `wire.kz` is the bearer token,
which is read once before the first turn and never changes. **Session state
lives in the store; a startup constant does not.**

The first version got that wrong and said so confidently. It held the
transcript in a `[16384]u8` module buffer, justified with *"a tor param inside
a SWEEP arm would be 690_234"* — copied from `wired/auth.kz`, where it had
been true, and never rechecked. **690_234 landed 2026-08-03 and is MUST_RUN
green.** `probe_store.k` in this directory settles it in twenty lines: a tor
whose parameter is the bridge reads a store-held String inside a sweep arm and
dispatches it. The hand-rolled buffer was also strictly worse than the store —
fixed at 16 KiB, oldest-wins-stops-growing, so a long enough conversation would
have silently stopped recording.

Worth being exact about what the store can and cannot do here, because the two
constraints get conflated. **Capacity is fixed static memory, but it bounds
ROWS, not bytes.** An owned-String column grows without limit (`690_053`,
`690_060`), which is why one growable String holds an unbounded conversation
today. What it cannot do is one row per MESSAGE — countable, replayable,
compactable, which is the shape a conversation actually wants. That is the one
fixed capacity would bite, and today's answer is a blob.

### The turn-2 failure that made this worth building

The first live run got turn 1 and turn 3 right and failed turn 2 with:

```
  model> I haven't opened a note yet, so I need to open one first:
  the model did not emit Koru: No flow found in source
```

The note was open on the bridge at that moment. `d_turns.k` cuts conversation
history explicitly — *"each send carries only the newest message"* — and that
cut is survivable in a chat client and fatal here. **A bridge that holds
resources across turns, paired with a model that remembers nothing, produces
an agent that reopens what it already has.** Persistence has two halves and we
had built one.

`wire.kz` now keeps the transcript and replays it, which is the whole fix.
Note what the model is reasoning from: it sees that it previously said
`open(...)` and that the prompt states the first handle is `note_0`. It is
inferring the handle, not being told it. Feeding the actual dispatch RESULT
back as a message is the honest next increment.

### What it does NOT do, and one of them is interesting

- **The vocabulary is stated twice.** `notes.kz` declares the agent's whole
  surface in `~std/runtime:register(scope: "notes")`, and `wire.kz` restates
  the same three events in English for the model. That is duplication with
  nothing keeping the halves in step, and only `event-denied` catches drift at
  runtime. Deriving the prompt from the scope declaration is the obvious move
  and there is no surface for it: `collect-scopes` walks the AST at compile
  time, but a running program cannot ask a scope what events it has.
- **The transcript is a blob, not rows.** One growable String, so nothing can
  count turns, replay the last N, or compact the middle. See above for why.
- **One invocation per turn.** `wire:clean` keeps the first line. A model that
  wants `open(…) |> append(…)` in one turn cannot say so.
- **`max_tokens: 100`, single model, hardcoded URL.** It is a demo.
