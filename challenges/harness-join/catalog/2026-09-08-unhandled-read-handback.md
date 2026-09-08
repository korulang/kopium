# unhandled-read-handback

The 08-07 ruling's hand-back, witnessed twice: canned on the wall, live by a
real model.

The notes scope had no named-branch verb — every failure was a printed
string — so nothing a model could emit produced an `unhandled-branch`.
`read` now returns `| ok | missing path`, and this replay adds the eighth
wall case: `notes-unhandled` (`probe_unhandled_read.py`) pins the four
shapes through the same lenient `std/bridge:run` that `live.k` calls —
bare-read-missing hands back, partial-handling hands back, bare-read-existing
hands back the `ok` branch (bytes still arrive), and a handled `ok`
completes. Then `live.k` turn 5 fired the hand-back for real
(`UNHANDLED branch=[missing]`) and turn 6 the model explained the semantics
back and continued.

Ran: `python3 bench/harness-check.py` → notes trio green (`notes-read`,
`notes-edit`, `notes-unhandled`). Live: 8-turn run, model
`meta/muse-spark-1.3-contributor`, hand-back observed on turn 5.

Would correct: the hand-back stops firing (regression in the lenient path),
or the wall's notes cases go red.
