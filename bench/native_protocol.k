// native-protocol.k — the hand-written tool surface, declarations only.
// Pure Koru (.k): no host lines. Proc bodies live in native_protocol.kz;
// the contract the model learns lives here.
//
// `!` marks the one real commitment — <held!>. Everything else is
// typed data: borrow-checked, discharge-free.

import std/runtime

// ------------------------------------------------------------------
// VOICE — the only verb the user hears
// ------------------------------------------------------------------
pub tor say { text: string } -> string

// ------------------------------------------------------------------
// READS — mint handles, never mutate. Cost 1.
// ------------------------------------------------------------------
pub tor list-all-airports {}
| airports string
| error string

pub tor calculate { expression: string }
| value string
| invalid string
| error string

pub tor get-flight-status { flight_number: string, date: string }
| reported string
| unknown string
| error string

pub tor search-direct-flight { origin: string, destination: string, date: string }
| results string<found>
| none string
| error string

pub tor search-onestop-flight { origin: string, destination: string, date: string }
| results string<found>
| none string
| error string

pub tor get-user-details { user_id: string }
| found string<user-known>
| missing string
| error string

pub tor get-reservation-details { reservation_id: string }
| found string<reservation-known>
| missing string
| error string

// ------------------------------------------------------------------
// COMPOSITION — borrow a minted set, produce a validated choice.
// Named branches: `chosen` mints, `miss` refuses membership.
// ------------------------------------------------------------------
pub tor select { flights: string<found>, flight_number: string, date: string }
| chosen string<chosen>
| miss string


// ------------------------------------------------------------------
// THE BOOKING OBLIGATION — hold is the commitment, confirm is the spend.
// `held` mints the pending commitment; `refused` names why it can't.
// ------------------------------------------------------------------
pub tor hold {
    user: string<user-known>,
    flights: string<chosen>,
    passengers: string,
    payment_id: string,
    amount: i64,
    cabin: string,
    flight_type: string,
    total_baggages: i64,
    nonfree_baggages: i64,
    insurance: string,
}
| held string<held!>
| payment-failed string
| refused string

pub tor release { held: string<!held> } -> string

pub tor confirm { held: string<!held> }
| booked string<reservation-known>
| declined string
| unavailable string
| error string

// ------------------------------------------------------------------
// MUTATIONS — borrow the reservation handle; the env-vended id comes
// out of the handle, so a fabricated reservation_id is a wire refusal.
// ------------------------------------------------------------------
pub tor cancel-reservation { reservation: string<reservation-known> }
| cancelled string
| ineligible string
| already-cancelled string
| error string

pub tor update-reservation-flights {
    reservation: string<reservation-known>,
    flights: string<chosen>,
    cabin: string,
    payment_id: string,
}
| updated string
| payment-failed string
| refused string
| error string

pub tor update-reservation-baggages {
    reservation: string<reservation-known>,
    total_baggages: i64,
    nonfree_baggages: i64,
    payment_id: string,
}
| updated string
| payment-failed string
| refused string
| error string

pub tor update-reservation-passengers {
    reservation: string<reservation-known>,
    passengers: string,
}
| updated string
| payment-failed string
| refused string
| error string

pub tor send-certificate { user: string<user-known>, amount: i64 }
| sent string
| insufficient string
| refused string
| error string

// ------------------------------------------------------------------
// ESCAPE HATCHES — cost 1, always available.
// ------------------------------------------------------------------
pub tor transfer-to-human-agents { summary: string }
| handed-off string
| error string

// ------------------------------------------------------------------
// GUIDES — recovery doctrine is keyed to the branches above and lives in
// app/airline_guides (the slot-free live table). The authored {{ }} spec
// is bench/guides/*.md; std/guide stays dumb and never interpolates.
// ------------------------------------------------------------------

// ------------------------------------------------------------------
// THE CONTRACT — scope documentation served with the vocabulary.
// Describes call shapes only; recovery doctrine lives in the guides.
// ------------------------------------------------------------------

[
- doc
# Tool contract — airline-native

Handles carry "quoted" JSON text — a found/chosen/user-known/
reservation-known/held binding's content is the payload string
the verb returned. Read fields out of it as JSON.

PHANTOM ARGS TAKE BINDING NAMES: where a signature demands
<found>, <chosen>, <user-known>, <reservation-known>, or <!held>,
pass the BARE rN name the minting arm issued (r6, r9, ...) — the
names in the bound-lines/you-hold listing. NEVER the id string,
never JSON inside, and never a field path: `r5.reservation_id`
unwraps the handle to the string and is refused identically to a
literal. A phantom arg that is not a bare held name dies before
the call runs.

ARM THE OUTCOME, NOT THE FALLBACK: `| found r |>` arms the branch
you expect (found, chosen, held, booked, cancelled, updated, sent,
reported, value, airports). `| error e |>` is the transport-failure
arm — arming it does not make the call succeed.

say(text: string) — the voice channel: what the user hears. Always
"quoted" — {{ }} inside splices bound values into the line. say is a
statement, not a pipeline step: put it on its own line and start the
next invocation on the following line — never append a continuation
arrow or outcome arm to say.

ONE CALL, ONE ARMED BRANCH: a call may arm at most one outcome branch —
emit the branch you expect. The interpreter stays lenient, but this
agent surface teaches the single-branch shape.

Reads (cost 1):
· list-all-airports() -> airports: string — every airport code/name.
· calculate(expression: string) -> value: string — arithmetic only.
· get-flight-status(flight_number, date) -> reported: string — live
  status for a flight the user names.
· search-direct-flight(origin, destination, date) -> results:
  string<found> — a result SET handle; content is a JSON array of
  flight objects. `none` means no flights matched.
· search-onestop-flight(same args) -> results: string<found> — same
  shape, one-stop itineraries.
· get-user-details(user_id) -> found: string<user-known> — profile
  JSON: user_id, name, payment_methods (object — its KEYS are the
  valid payment_id values), reservations. `missing` = no such user.
· get-reservation-details(reservation_id) -> found:
  string<reservation-known> — reservation JSON: reservation_id,
  flight numbers/dates, passengers, cabin, status. `missing` = no
  such reservation.

Composition:
· select(flights: string<found>, flight_number, date) -> chosen:
  string<chosen> — validates flight_number+date AGAINST the <found>
  set's content; `miss` = not in that set (or stale set — search
  again). `chosen` content is the single selected flight JSON.

Booking (the obligation):
· hold(user, flights, passengers, payment_id, amount, cabin,
  flight_type, total_baggages, nonfree_baggages, insurance) -> held:
  string<held!> — prepares book_reservation args WITHOUT spending.
  payment_id must be a KEY of the user record's payment_methods.
  passengers is "quoted" JSON array text — objects carrying
  first_name, last_name, and dob in YYYY-MM-DD form.
  `payment-failed` = the env rejected the payment id; `refused` =
  args/policy refused.
· release(held: string<!held>) -> string — abandons the hold free.
  The ONLY safe exit for a hold you cannot confirm.
· confirm(held: string<!held>) -> booked: string<reservation-known>
  — spends the hold into book_reservation. `declined` = payment
  refused at commit; `unavailable` = fare/seat gone since hold.

Mutations (borrow the handle; env-vended id comes out of it):
· cancel-reservation(reservation) -> cancelled | ineligible |
  already-cancelled.
· update-reservation-flights(reservation, flights: string<chosen>,
  cabin, payment_id) -> updated | payment-failed | refused.
· update-reservation-baggages(reservation, total_baggages,
  nonfree_baggages, payment_id) -> updated | payment-failed | refused.
· update-reservation-passengers(reservation, passengers) ->
  updated | payment-failed | refused.
· send-certificate(user, amount) -> sent | insufficient | refused.

Escape:
· transfer-to-human-agents(summary) -> handed-off — last resort,
  costs the session's remaining autonomy.

Every verb's residual `error` is transport/environment failure —
not a domain outcome. Named branches are the states; treat them as
such.
]
pub tor contract {} -> string

// ------------------------------------------------------------------
// THE REGISTRY — what the scope declares. Order is load-bearing:
// release before confirm (auto-discharge must never book).
// ------------------------------------------------------------------
std/runtime:register(scope: "airline-native") {
    say(1)
    list-all-airports(1)
    calculate(1)
    get-flight-status(1)
    search-direct-flight(1)
    search-onestop-flight(1)
    get-user-details(1)
    get-reservation-details(1)
    select(2)
    hold(2)
    release(1)
    confirm(10)
    cancel-reservation(10)
    update-reservation-flights(10)
    update-reservation-baggages(10)
    update-reservation-passengers(10)
    send-certificate(10)
    transfer-to-human-agents(1)
}
