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
pub tor say { text: string }

// note(text:) — observer lane. Reaches nobody user-facing; the agent
// transcript lands it as an `observer:` message so reasoning stays visible
// without becoming an answer.
pub tor note { text: string }

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
// THE REGISTRY — what the scope declares. Order is load-bearing:
// release before confirm (auto-discharge must never book).
// ------------------------------------------------------------------
std/runtime:register(scope: "airline-native") {
    say(1)
    note(1)
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
