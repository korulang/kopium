# kopium-headless — an agent whose only tool is a Koru interpreter

`kopium/d_turns.k` is the wired client: vaxis chrome, curl multi + SSE, replies
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

The bridge surface used here (`std/bridge:run`, void `close`, the possession
check) is on the koru branch `bridge-honesty`. Build with that worktree's
`koruc` until it lands on main.
