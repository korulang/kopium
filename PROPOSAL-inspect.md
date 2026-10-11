# Bound Value Inspect Affordance

## Problem

Bound values are durable and passable (`r17.user_id` can feed a later call),
but they are not readable in the wire. The payload appears once in a step
report, then becomes write-only. Models respond by inventing surface forms
such as `note: fs.status`, which are literal prose, not reads.

The affordance should keep the one-surface law: inspection must be a Koru
invocation, not a side channel or JSON result outside the interpreter.

## Proposed Verb

Grant an introspection host verb beside `vocabulary`, `grammar`, `bind`, and
`note`:

```koru
inspect(name: r17)
inspect(name: r17.status)
```

Result:

```koru
| ok v |>
```

The `ok` payload is the same interpreter `Value` render used in step reports,
and `std/bridge:run` auto-binds it like any other result. A model can then say
or branch from it in ordinary wire:

```koru
inspect(name: r17.status)
| ok status |> say: Your reservation is {{ status }}
```

If interpolation is not available for `Source`, the model can still inspect
first and use the returned scalar in a typed field or ask the user-facing text
in a follow-up `say:` once Source interpolation exists.

## Semantics

- `inspect(name: rN)` reads a session binding by name.
- `inspect(name: rN.field)` reads a field on a bound record payload.
- It has no side effects and mints no obligations.
- It is a normal host verb: visible only when `create(introspection: true)`
  grants the introspection vocabulary.
- The returned value is durable because the bridge auto-binds every result.

## Failure Modes

- Unknown binding: `validation-error: binding 'rN' is not bound`.
- Unknown field: `validation-error: field 'status' is not on rN`.
- Non-record field access: `validation-error: rN has no fields`.
- Malformed path: `parse-error`, same grammar wall as other wire.
- Ungranted session: `event-denied: inspect`.

These failures should be typed and teach the legal spelling. They should not
fall back to literal text, because literal echo is the defect being fixed.

## Composition With Arms

`inspect` composes like any other verb:

```koru
inspect(name: r12)
| ok data |> note: checking the held value before writing
```

Named failure branches are not necessary if missing data is a grammar/session
error rather than domain state. If a softer form is wanted later, add a second
verb:

```koru
try-inspect(name: r12.status)
| found v |>
| missing m |>
```

Keep the first version strict. The current defect is not optional missing data;
it is the absence of a lawful read.

## Why Not Interpolated Reads First

Interpolating `rN.field` inside `say:` or `note:` would be useful, but it
changes `Source` semantics and every captured-text field at once. A host verb
is the smaller first move: derived prompt, parse gate, session lookup, and
branch composition all stay inside the existing Koru invocation surface.

