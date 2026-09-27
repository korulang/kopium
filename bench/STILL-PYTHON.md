# STILL-PYTHON — how far this is from a Koru-driven harness

*2026-09-27. Companion to CONTAMINATION-2026-09-27.md. That document covers
the coaching channel — prose injected into the measured prompt. This one
covers the deeper dishonesty: the harness was supposed to be driven by
Koru, and it is not. The gate validates the wire; Python decides what the
wire means.*

The claim this repo makes — "anything the agent outputs goes to a Koru
interpreter" — is true at the parse layer and false at the semantic
layer. Below is the full inventory of what Python still owns, in
`bench/kopium_agent.py`, that the vision assigns to the language.

## What Python decides that the wire should

### 1. Verb kinds live in Python constants, not in the declaration

```python
_SPOKEN = {"say"}
_LOCAL  = {"vocabulary", "grammar", "bind"}
koru_to_tau = { "get-user-details": "get_user_details", ... }
```

The register block (`airline_tools.kz`, generated) declares that verbs
*exist*. Python alone decides what they *mean to the marshal*: `say` is
speech, `vocabulary` is introspection, everything else is an environment
call, and each has a southbound spelling. A new domain needs a `.kz` file
**and** a Python config — the "one declaration → working agent for N
domains" claim is half-built. The kind of a verb (speech / env /
introspection) is a property of the verb; it belongs on the `tor`, where
the guard and the grammar can see it.

### 2. Python re-parses the wire the interpreter already parsed

`_item_chains` (kopium_agent.py:410) segments the reply into items and
verb chains with its own regexes; `_say_texts` (:446) extracts `say(text:
"...")` arguments with a second regex. The gate parsed this wire
correctly once — but its STEPS report doesn't carry the structure back,
so the adapter re-derives it approximately. Two parsers for one language
is a permanent drift class: any wire feature the regexes don't model
(forward refs, nested chains, defines mid-turn) is silently mis-marshaled
rather than refused.

### 3. Python authors the model's teaching feedback

Every string the model learns from at runtime is hand-written Python:

- `_rejection_note` (:270) — "your last reply was not accepted…"
- `_vocabulary_hint` (:251) — "…is not a verb in your vocabulary"
- `_note_speech_dropped` (:463) — "the user never heard this…"
- `_note_calls_dropped` (:470) — "a chain's earlier calls did not
  execute…"

This is the same editability class as `extra_rules` — hand-authored
behavioral prose reaching the model — delivered as context notes instead
of system prompt. `prompt_guard.py` does not scan these. Nothing today
stops a future "hint" from carrying coaching content into a run; only
review does. The rejection/feedback render belongs to the gate, where it
is generated from the grammar, not authored per-incident.

### 4. Python edits the agent's output before the interpreter sees it

`_clean_reply` (:367) strips `<think>` tags and markdown fences from the
reply before the gate judges it. The premise was absolute: anything the
agent emits is Koru source, and malformed source is refused with
feedback. The strip exists because refusing conditioning junk cost turns
— a real measurement — but it means the record of what the agent
actually emitted is laundered before the interpreter judges it. The gate
should own this decision (a reject-class for decoration, or an explicit
unwrapping rule in the grammar), so the wire contract is one artifact.

### 5. Half-duplex policy is authored, not declared

Which calls run now, which speech is deferred, how refusals are phrased
to the user after three failed attempts — all Python control flow. The
mechanics are forced (tau2 is Python), but the *policy* — "calls execute,
speech is preserved as a next-turn note" — is a semantic decision living
in the adapter where it can be silently changed without touching the
language.

### 6. The system prompt's prose is still Python-authored

Bounded now by the guard (no domain verbs, fixed section inventory), but
the intro paragraph and `## Growth` text are f-strings in the adapter.
The end-state has the *entire* prompt emitted by the gate as generated
data — the Python side holding zero prompt strings.

## What is legitimately Python

The transport: litellm calls, tau2 `Message`/`ToolCall` construction, the
gate subprocess, the stall watchdog, usage/cost accounting. That is the
boundary the benchmark imposes, and it should be *only* that.

## The distance, stated plainly

| Vision | Today |
|---|---|
| Register block declares the domain, completely | `.kz` declares verbs; Python declares their marshaling kind |
| Interpreter owns parse AND semantics | Interpreter owns parse; Python owns dispatch policy |
| Teaching feedback is the language's voice | Feedback is Python f-strings the guard can't see |
| Agent output is judged as emitted | Python cleans it first |
| Prompt is generated data | Prompt is generated blocks wrapped in authored prose |

The fix is not another rule file — it is moving each of these six into
the language: verb kinds on `tor` declarations, a structured turn plan
from the gate (verbs + args + kinds, so Python never re-parses),
gate-generated rejection renders, and a prompt that is 100% emitted
output. Until then this is a Python harness with a Koru validator in the
middle — better than a coached one, but not the thing this project set
out to build.
