# Hole 9 — the wire grammar's worked example is notes-shaped

**Found:** 2026-09-16, third-vocabulary probe (`headless/calc.kz` +
`probe_calc.k`) — a domain with no handles, no `open`, no `append`.
**Confidence it's real:** 100% (measured; the example text is fixed bytes
at `koru/koru_std/runtime.parsewire.kz:33`).

## What it looks like

`std/bridge:grammar` renders `WIRE_GRAMMAR_TEXT` above the scope's
derived verb list. The shape rules are fixed prose — fine — but the
chain rule's *worked example* is concrete notes vocabulary:

    Chain fresh outcomes with arms:
    `open(path: "n") | ok h |> append(handle: h, text: "x")` — the
    binding `h` is the handle the call just issued.

On `calc` the model is taught two verbs the vocabulary wall will
`event-deny`, and a "handle" semantics nothing in the domain mints. The
vocabulary list below is derived; the example above it is secretly the
first domain's. `notes` and `ledger` could not see this — both mint
opaque handles, so "bind the handle the call just issued" was true in
both; only a handle-free scope makes the assumption visible.

## Why it is worth a hole of its own

The north-star claim is that the register derives the prompt — and the
prompt is what the model learns the world from. An example naming verbs
that will be refused teaches a lesson the wall then punishes; an
example narrating handles in a handle-free domain teaches a discipline
with no referent. The mis-teaching is silent: nothing in the wire's own
machinery flags it, because the check that would (vocabulary membership)
fires only on the *model's* output, not ours.

This is also the first seam the runtime cannot be blamed for: every
prior hole was dispatch/emission/enforcement — this one is in the
derived surface itself, the channel the whole endeavor exists to make
honest.

## The want

Either:

- **Derive the example.** The scope table already carries `branches_fn`
  and `input_fn` — enough to synthesize a chain example from the scope's
  own verbs (`add(a: "2", b: "40") | sum s |> say(text: s)` on calc;
  `open-acct(...) | ok h |> post(handle: h, ...)` on ledger). A
  vocabulary with no payload-carrying verb gets the binding rule without
  a fabricated cast.
- **Or de-domain the prose.** The rule stays, the example goes
  generic — no invented verb spellings at all.

A ruling between them (or a third shape) is Lars's — the text is
model-facing prompt, and its wording is a spelling.

## Repro / settler

```bash
sh wired/holes/9_grammar_example_is_notes_shaped/settler.sh
# exit 0 = hole OPEN (example names verbs the scope refuses)
# exit 1 = hole CLOSED (every example verb is in the vocabulary)
# exit 2 = unmeasured (repro failed to build/run)
```

## Verdict — OPEN 2026-09-16
