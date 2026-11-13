// native-protocol.k — the hand-written tool surface, declarations only.
// Pure Koru (.k): no host lines. Proc bodies live in airline_native.kz;
// the contract the model learns lives here.
//
// PHANTOM VOCABULARY — types that carry obligation state:
//   string<found>             a search result set the env minted
//   string<chosen>            a flight selection validated AGAINST it
//   string<user-known>        a user profile the env vended
//   string<reservation-known>  a reservation handle (borrow — reads only)
//   string<held!>              a pending book_reservation commitment
//   `!` marks a real commitment — only <held!> carries it. Every other
//   phantom is typed data: borrow-checked, forgery-proof, no discharge
//   owed. A literal where a phantom is demanded refuses BEFORE the proc
//   runs — invented ids are wire-level errors, not env roundtrips.
//   Stale handles expire ambiently: a new search-* retires the prior
//   <found> inside the proc — old results SHOULD go stale.
//
// BRANCHES ARE THE PROTOCOL — outcomes are named arms, not ok/error
// strings. `| chosen`/`| miss`, `| held`/`| refused` teach the model
// the workflow's real branches; phantom types ride the arm payload.
//
// OBLIGATION LIFECYCLE:
//   search-* mints <found!>  ->  select borrows it, mints <chosen!>
//   get-user-details mints <user-known!>
//   hold(user, flights, ...) mints <held!> — prepared args, unspent
//   release(held) spends it free          — hang-up path
//   confirm(held) spends it INTO book_reservation — the one commit
//   release is registered BEFORE confirm: auto-discharge on hang-up
//   releases, never books.
//   No drop-* verbs: non-commitment handles owe no discharge. <held!>
//   is the only obligation — release spends it free, confirm spends it
//   into book_reservation, hang-up auto-releases.

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
// GUIDES — doctrine rows keyed to the branches above. These fire at
// dispatch, once per session, at the first resolution to their key.
// Domain-general only: field truth, workflow rules, recovery patterns —
// never task ids, names, or answers.
//
// TEMPLATE CONTRACT (spec): guide text carries {{ slot }} references
// that resolve against the reply/session binding context at fire time —
// same one-level lift as say text. A slot with no bound source renders
// as an explicit MISSING marker, telling the agent it must produce the
// binding before the call is valid — the guide names its own
// precondition instead of silently blanking.
// ------------------------------------------------------------------

import std/guide

// `missing` on a lookup means the id is wrong or invented — resolve it,
// never fabricate. This is the task-10 lesson as a branch.
std/guide:add(get-reservation-details -> missing) { No reservation under that id — it was invented or mistyped. The real ids live in {{ reservations }} on the user record, or ask the user for the confirmation number, then retry. Never pass a placeholder. }

std/guide:add(get-user-details -> missing) { No user under that id — check the id the user gave you, or ask them to confirm it. user_id comes from the user's message or {{ user_id }} on a reservation record — never invent one. }

// `payment-failed` names the recurring tau2 failure: payment_id must be
// a KEY of the user record's payment_methods object — never invented.
std/guide:add(hold -> payment-failed) { That payment_id is not one of this user's payment methods. The valid ids are the keys of {{ payment_methods }} on the user record — read them from the <user-known> handle's content, or ask the user which method to use. }

std/guide:add(confirm -> declined) { The payment was declined at commit time — the held args carried {{ payment_id }} the env rejected. Release the hold (release(held: ...)), re-check it against {{ payment_methods }}, and hold again. }

std/guide:add(confirm -> unavailable) { The held itinerary is no longer bookable — a leg sold out or the route closed between hold and confirm. Release the hold, search again for fresh options, and re-select. }

std/guide:add(cancel-reservation -> ineligible) { Policy refused the cancellation — the usual causes are the 24-hour window, basic-economy fares, or missing travel insurance. Read the reason in the payload, explain it to the user plainly, and offer transfer-to-human-agents if they insist. }

std/guide:add(select -> miss) { That flight_number is not in the search result you selected from — select may only name what a search minted. Re-check {{ flights }} in the <found> handle's content for the exact flight_number, or search again. }

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
