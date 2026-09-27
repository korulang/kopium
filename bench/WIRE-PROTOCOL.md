# Wire protocol

The gate binaries (`airline-gate-binary`, `mock-gate-binary`) are the bridge's
stdin/stdout surface. One grammar for humans and agents: whatever a model
emits as a reply is exactly what a human types into the binary's stdin. There
is no command channel.

## Input

A **turn** is one or more lines of Koru wire source, terminated by a blank
line (EOF also terminates). Each non-empty line is one wire item.

An **item** is one of:

- an invocation: `verb(field: value, ...)`
- an invocation with arms: `verb(...) | branch bind |> next-verb(...)`
- a definition: `tor name { params }` on one line, the body on the next

### Argument values

| form | meaning |
|---|---|
| `"text"` | string literal |
| `42`, `3.5` | numeric literal — parsed against the declared field type |
| `true`, `false` | boolean literal |
| `name` | bound name — an earlier arm binding or a session binding (`r1`, `t3`), else refused |
| `name.field` | field of a bound value — refused loudly if absent |

Typed fields are strict: `send-certificate(user_id: "u", amount: "fifty")`
refuses with `field 'amount' expected i64, got 'fifty'`. A missing declared
field refuses the same way (`got ''`). There is no silent coercion and no
zero-default.

Arms chain a call's outcome to the next call. `| ok v |>` binds the result
and continues; a branch with no matching arm halts the program and reports.
Flat `|>` arms on one line are siblings of the head invocation — deeper
chaining needs the multi-line source form.

## Output

Exactly one response per turn:

| prefix | meaning |
|---|---|
| `OK <verb> bound=<name> <json>` | the invocation ran; `<json>` is `{"branch":"","value":<result>}` and `<name>` (`r1`, `r2`, …) is the name the result is bound under for the rest of the session |
| `HALT <verb> <branch> <payload> held: <handles>` | a step returned a branch no arm matched; execution stopped with state |
| `STEPS-BEGIN … STEPS-END` | multi-item turn: framed report, one `step n/m result: <json> bound: <name>` or `step n/m <error>: <msg>` line per item |
| `DEFINED <name>` | a `tor` definition was installed into the session vocabulary |
| `REJECT <detail>` | the wire refused it: not an invocation, unbound name, unknown field, event denied |
| `ERROR <detail>` | dispatch/validation failure — typed-arg refusals land here with teaching text |

The `value` inside an `OK`/`step` payload is the called tor's own echo: the
gate's procs serialize their parsed inputs to JSON, so the harness reads
arguments without re-parsing Koru. Types inside it are real — `i64` fields
produce JSON numbers, string fields produce JSON strings, JSON-in-string
params (e.g. `flights`) produce real arrays.

## Introspection

`vocabulary()`, `grammar()`, and `bind(name:, value:)` are ordinary wire
verbs, not commands. They exist only because the gate creates its bridge
with `introspection: true`; without that grant they are `event-denied`
like any other unvocabularied word. `vocabulary()`/`grammar()` return the
session's current vocabulary (registered + defined + bound names) and
derived grammar as values in a normal `OK` payload. `bind` writes a datum
into the session env under a caller-chosen name — it is how a harness
hands an out-of-band tool result back into the agent's world (`t{N}`).

There is no `.`-prefixed channel. `.vocabulary` is a syntax error:
`REJECT not an invocation: a wire line is verb(field: "value") and starts
with a verb name, not '.'`. Introspection is progressive disclosure by
capability grant, not a fixed system-prompt blob.

## Session state

One bridge per process. Everything a turn defines (`tor …` → `DEFINED`) joins
the live vocabulary for the rest of the session and appears in
`vocabulary()` output. Handles acquired and not discharged are reported on
the `HALT` line's `held:` field.

Values persist the same way definitions do. Every `result` is auto-bound
`r{N}` on the session env and seeded into later runs, so `r1.user_id`
resolves turns after the call that produced it. A JSON-object result also
exposes its members as fields (`r1 {user_id, name}` in `vocabulary()`).
The `bind` verb injects out-of-band data under a caller-chosen name —
`kopium_agent.py` binds each southbound tool result `t1`, `t2`, … and
renders `[t3] {datum}` into the model's context, so a later turn writes
`t3.amount` instead of re-typing JSON text. A name no turn bound still
fails loudly: `unbound 'r9' on 'echo' — bind it with an arm …`.

## Python

`gate_session.py` is a thin wrapper over the same bytes: `send()` writes a
turn and reads the status line; `parse_ok()` splits `verb`/`bound`/json;
`bind(name, value)` drives the injection verb; `vocabulary()`/`grammar()`
call the wire verbs through `send()` and unwrap the `value`.
