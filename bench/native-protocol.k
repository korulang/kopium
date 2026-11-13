// native-protocol.k — the hand-written tool surface, declarations only.
// Pure Koru (.k): no host lines. Proc bodies live in airline_native.kz;
// the contract the model learns lives here.
//
// PHANTOM VOCABULARY — types that carry obligation state:
//   string<found!>             a search result set the env minted
//   string<chosen!>            a flight selection validated AGAINST it
//   string<user-known!>        a user profile the env vended
//   string<reservation-known>  a reservation handle (borrow — reads only)
//   string<held!>              a pending book_reservation commitment
//   `!` marks mint-on-produce; absence marks borrow-only.
// A literal string where a phantom is demanded refuses BEFORE the proc
// runs — invented ids are wire-level errors, not env roundtrips.
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
//   drop-*(handle) retires a live handle early; describe-handles()
//   lists what the session currently holds.

import std/runtime

// ------------------------------------------------------------------
// VOICE — the only verb the user hears
// ------------------------------------------------------------------
pub tor say { text: string } -> string

// ------------------------------------------------------------------
// READS — mint handles, never mutate. Cost 1.
// ------------------------------------------------------------------
pub tor list-all-airports {}
pub tor calculate { expression: string }
pub tor get-flight-status { flight_number: string, date: string }

pub tor search-direct-flight { origin: string, destination: string, date: string }
| ok string<found!>
| error string

pub tor search-onestop-flight { origin: string, destination: string, date: string }
| ok string<found!>
| error string

pub tor get-user-details { user_id: string }
| ok string<user-known!>
| error string

pub tor get-reservation-details { reservation_id: string }
| ok string<reservation-known>
| error string

// ------------------------------------------------------------------
// COMPOSITION — borrow a minted set, produce a validated choice.
// Named branches: `chosen` mints, `miss` refuses membership.
// ------------------------------------------------------------------
pub tor select { flights: string<found>, flight_number: string, date: string }
| chosen string<chosen!>
| miss string

pub tor drop-search { found: string<!found> } -> string
pub tor drop-choice { chosen: string<!chosen> } -> string
pub tor drop-user { user: string<!user-known> } -> string
pub tor drop-reservation { reservation: string<!reservation-known> } -> string

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
| refused string

pub tor release { held: string<!held> } -> string

pub tor confirm { held: string<!held> }
| ok string<reservation-known!>
| error string

// ------------------------------------------------------------------
// MUTATIONS — borrow the reservation handle; the env-vended id comes
// out of the handle, so a fabricated reservation_id is a wire refusal.
// ------------------------------------------------------------------
pub tor cancel-reservation { reservation: string<reservation-known> }
| ok string
| error string

pub tor update-reservation-flights {
    reservation: string<reservation-known>,
    flights: string<chosen>,
    cabin: string,
    payment_id: string,
}
| ok string
| error string

pub tor update-reservation-baggages {
    reservation: string<reservation-known>,
    total_baggages: i64,
    nonfree_baggages: i64,
    payment_id: string,
}
| ok string
| error string

pub tor update-reservation-passengers {
    reservation: string<reservation-known>,
    passengers: string,
}
| ok string
| error string

pub tor send-certificate { user: string<user-known>, amount: i64 }
| ok string
| error string

// ------------------------------------------------------------------
// ESCAPE HATCHES — cost 1, always available.
// ------------------------------------------------------------------
pub tor transfer-to-human-agents { summary: string }
| ok string
| error string

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
    drop-search(1)
    drop-choice(1)
    drop-user(1)
    drop-reservation(1)
}
