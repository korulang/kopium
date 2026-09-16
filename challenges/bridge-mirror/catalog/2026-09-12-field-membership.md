# 2026-09-12-field-membership — unknown fields are never refused, on any turn shape

Construct: **field-membership validation** — `verb(known: "x", bogus: "y")`
should be `validation-error` at dispatch, per the `runtime.parsewire.kz`
header: "an unknown field on a known verb is `validation-error` at
dispatch."

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`,
`say` declares `{ text: string }` only):

| surface | `say(text: "x", bogus: "3")` | class |
|---|---|---|
| single-item | ~~**result** — `say` printed `x`; `bogus` silently ignored~~ **CLOSED koru `b4742ff96`**: `validation-error` naming the field; pinned by `440_025` | supported (was gap) |
| multi-item step | ~~**result** — same~~ step N/M `validation-error` naming the field | supported (was gap) |

The comment promises a refusal the dispatch never performs — `say` read
`text` and ignored the foreign field. Whether this is an unimplemented
validator or a deliberate tolerance, the doc now lies about it: the
parsewire header describes an enforcement that does not exist on either
turn shape.

For the transfer map this matters less than the silent-execution cells —
a model that invents a field gets a successful-looking result, which is
bad teaching but not a corrupted action — but it is exactly the kind of
seam the map is for: a claimed boundary that isn't there.

Disposition: either dispatch gains the field-membership check the comment
describes (koru-side, `interpreter`/`runtime` validation), or the comment
is corrected to say fields are tolerated. A ruling is owed; the card does
not pick it.

Would correct this row: `say(text: "x", bogus: "3")` reports
`validation-error` naming `bogus`, or the parsewire header stops claiming
it refuses.

**Settled 2026-09-14 (koru `b4742ff96`):** the "would correct" row runs —
`bogus` is `validation-error` naming the field on the head call, a
mid-turn step, and a nested arm-body call, and a name outside the
vocabulary stays `event-denied`. The mechanism is the derived one:
`validateFlow` judges provided fields against the scope's own
`get_event_input` table — the same registry data the prompt and
dispatcher are emitted from — so the refusal cannot drift from the
declaration. `get_event_input_<scope>` now answers null for a name the
scope doesn't own, which is what lets vocabulary membership and field
membership stay distinct questions. Koru pin `440_025`.
