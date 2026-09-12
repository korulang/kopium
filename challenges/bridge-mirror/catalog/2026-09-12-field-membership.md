# 2026-09-12-field-membership — unknown fields are never refused, on any turn shape

Construct: **field-membership validation** — `verb(known: "x", bogus: "y")`
should be `validation-error` at dispatch, per the `runtime.parsewire.kz`
header: "an unknown field on a known verb is `validation-error` at
dispatch."

Measured this session (kopium `main`, canned `std/bridge:run` on `notes`,
`say` declares `{ text: string }` only):

| surface | `say(text: "x", bogus: "3")` | class |
|---|---|---|
| single-item | **result** — `say` printed `x`; `bogus` silently ignored | gap |
| multi-item step | **result** — same | gap |

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
