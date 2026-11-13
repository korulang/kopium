// airline_guides.k — the airline domain's doctrine table: domain-general
// teaching rows compiled into the gate/agent binaries as `std/guide` data.
//
// Provenance (train-30 ONLY; test-20 is frozen and never read):
//   - field truth: `airline_tools.k` (generated from tau2's openai_schema)
//     and the real payload field sets mined from
//     `corpus/combined-r2r3-callstep.jsonl` (2,790 records / 2,335
//     dispatches, r2+r3 train-30 regen);
//   - workflow exemplars: canonical verb sequences counted from the same
//     corpus (e.g. get-user-details → get-reservation-details → book);
//   - judgment frames: `tau2-bench/data/tau2/domains/airline/policy.md`.
//
// Keys are `tor` for facts true of every dispatch of a verb, and
// `tor -> branch` for what one resolved outcome means / where it goes
// (the generated airlines declare `| ok | error`). Templates carry SLOTS,
// never task ids, passenger names, or reservation ids. Each row fires at
// most once per session, at the first dispatch that resolves to its key.

import std/guide

// ============================================================================
// FIELD TRUTH — the actual arg names and the real payload fields.
// Derived from airline_tools.k signatures + corpus payload key sets.
// ============================================================================

std/guide:add(get-user-details) { Takes user_id. The profile returns: user_id, name (object {first_name, last_name}), email, dob, address (object {address1, address2, city, state, country, zip}), membership (regular|silver|gold), reservations, saved_passengers (list of {first_name, last_name, dob}), and payment_methods as an OBJECT keyed by payment id, each {source, id, brand, last_four, amount}. Wire templates lift ONE level only: {{ u.user_id }} works, {{ u.name.first_name }} refuses — render {{ u.name }} for a nested object. There is no top-level list of payment methods and no `baggages` field — read the payment ids as the KEYS of payment_methods. }

std/guide:add(get-reservation-details) { Takes reservation_id. If you don't have one yet, get it first: get-user-details returns the user's reservations list, or ask the user for the confirmation number — never pass a placeholder like "your_reservation_id". Returns reservation_id, user_id, origin, destination, flight_type (one_way|round_trip), cabin, flights (list of {flight_number, date, origin, destination, price}), passengers (list of {first_name, last_name, dob}), payment_history (list of {payment_id, amount}), total_baggages, nonfree_baggages, insurance, created_at, status. Wire templates lift ONE level only: {{ r.origin }} works, {{ r.flights.0.flight_number }} or deeper refuses — render {{ r.flights }} for the list. Paid amounts are payment_history[].amount — a reservation has no payment_methods field and no payment_methods/id composite. }

std/guide:add(get-reservation-details -> error) { Reservation not found means the id is wrong or invented — never pass placeholders. Get the real id from get-user-details (its reservations list) or ask the user for the confirmation number, then retry. }

std/guide:add(search-direct-flight) { Takes origin, destination, date (YYYY-MM-DD IATA codes). Returns a LIST of flights, each {flight_number, origin, destination, date, status, available_seats.basic_economy/.economy/.business, prices.basic_economy/.economy/.business}. Choose by prices.<cabin>; only status "available" can be booked. }

std/guide:add(search-onestop-flight) { Takes origin, destination, date. Each result is an ORDERED LIST of legs (not one flight object); copy each leg flight_number and date in order. Same status/seat/price fields as search-direct-flight. }

std/guide:add(book-reservation) { All eleven args are REQUIRED: user_id, origin, destination, flight_type ("one_way"|"round_trip"), cabin ("basic_economy"|"economy"|"business"), flights, passengers, payment_methods, total_baggages (integer), nonfree_baggages (integer), insurance ("yes"|"no"). The three composite args are JSON text in a double-quoted string: flights="[{flight_number,date}]", passengers="[{first_name,last_name,dob}]", payment_methods="[{payment_id,amount}]". Omitting any arg fails the call before the database sees it. }

std/guide:add(update-reservation-flights) { Takes reservation_id, cabin, flights (JSON text: [{flight_number,date}]), payment_id (ONE id from the user profile). Origin, destination, and flight_type must stay unchanged; cabin must be the same on every flight. }

std/guide:add(update-reservation-baggages) { Takes reservation_id, total_baggages (integer), nonfree_baggages (integer), payment_id. total_baggages is the new absolute allowance, not a delta. }

std/guide:add(update-reservation-passengers) { Takes reservation_id, passengers (JSON text: [{first_name,last_name,dob}]). The number of passengers cannot change — supply the full new list, same count. }

std/guide:add(cancel-reservation) { Takes reservation_id only. Returns the cancelled reservation JSON. }

std/guide:add(get-flight-status) { Takes flight_number and date (YYYY-MM-DD). Returns one status word: available | delayed | on time | flying. Only "available" flights can be booked; "delayed"/"on time" have not taken off but cannot be booked; "flying" has taken off. }

std/guide:add(calculate) { Takes expression as math text in quotes, e.g. "198 + 129". Returns a number — quote it rather than recomputing by hand. }

std/guide:add(list-all-airports) { Takes no args. Returns [{iata, city}]; use the iata code in every origin/destination argument, never the city name. }

std/guide:add(transfer-to-human-agents) { Takes summary (one line of facts). It ENDS the exchange: after the call, send exactly "YOU ARE BEING TRANSFERRED TO A HUMAN AGENT. PLEASE HOLD ON." Nothing you write after that reaches the user. }

std/guide:add(send-certificate) { Takes user_id and amount (integer dollars). This is a gesture of compensation, not a refund mechanism — issue it only after confirming the complaint facts and the membership/insurance condition. }

// ============================================================================
// WORKFLOW EXEMPLARS — canonical successful sequences, templates with slots.
// Counted from the train-30 corpus (2,335 dispatches); no task data baked in.
// ============================================================================

std/guide:add(get-user-details -> ok) { Profile in hand. Next, read the reservation: get-reservation-details(reservation_id: "<id from the user reservations>") and arm its ok result. Take payment ids from the keys of payment_methods and passenger details from saved_passengers. }

std/guide:add(get-reservation-details -> ok) { Read flights[].flight_number and .date, cabin, total_baggages/nonfree_baggages, and payment_history[].payment_id. To change flights: search-direct-flight(origin, destination, date), then update-reservation-flights(reservation_id, cabin, flights, payment_id). To cancel: the API does NOT check the rules — cancel-reservation only if created_at is within 24h, cabin is business, the airline cancelled a flight, or insurance covers the reason, and no segment has flown; otherwise transfer-to-human-agents. }

std/guide:add(search-direct-flight -> ok) { Pick one result by prices.<cabin> and keep its flight_number and date. No direct flight fits? search-onestop-flight(origin, destination, date). To book: book-reservation(user_id, origin, destination, flight_type, cabin, flights: "[{flight_number, date}]", passengers, payment_methods, total_baggages, nonfree_baggages, insurance). }

std/guide:add(search-onestop-flight -> ok) { Each result is a leg list — put each leg flight_number and date, in order, into the flights array. }

std/guide:add(book-reservation -> ok) { The reply is the new reservation JSON: keep reservation_id, and confirm the itinerary, the total, and the payment split to the user. }

std/guide:add(cancel-reservation -> ok) { The refund returns to the original payment methods within 5-7 business days — tell the user. The API does NOT check the cancellation conditions: next time verify before calling that one holds (booked within the last 24h, airline cancelled the flight, business cabin, or travel insurance covering the reason), and if any segment has already flown, transfer instead. }

std/guide:add(update-reservation-flights -> ok) { Reply is the updated reservation. If baggage also changed, follow with update-reservation-baggages(reservation_id, total_baggages, nonfree_baggages, payment_id). }

std/guide:add(update-reservation-baggages -> ok) { Reply is the full reservation. Bags can be added but never removed; each extra checked bag is 50 dollars — state the charge. Insurance cannot be added after booking. }

std/guide:add(update-reservation-passengers -> ok) { Reply is the full reservation. Passengers can be edited but the count cannot change. }

std/guide:add(calculate -> ok) { The result is a number; quote it in the say that follows. }

// ============================================================================
// JUDGMENT FRAMES — adjudication at refusal/surprise edges, from policy.md.
// These are teaching rows, not retries: the failure names a policy condition.
// ============================================================================

std/guide:add(book-reservation -> error) { A booking failure is a policy condition, not a retry. The sum of payment_methods amounts must EQUAL the computed total exactly; every payment id must already be in the user profile; at most one travel certificate, one credit card, three gift cards; a certificate remaining balance is not refundable. Recompute price x passengers + 50 per extra bag + 30 per passenger insurance, then re-split the payment. Read the error payload: "amount does not add up" vs "not enough balance" are different fixes. }

std/guide:add(update-reservation-flights -> error) { A flight-change failure is usually payment: the single gift card or credit card must be in the profile and cover the difference. Also check the itinerary rules before retrying — basic economy cannot change flights, and origin, destination, and trip type must not change. Read the payload before choosing a different card. }

std/guide:add(get-user-details -> error) { The id is not in the database. Re-read the exact id the user gave; never invent or normalize one. If they cannot produce it, ask. }

std/guide:add(get-flight-status -> ok) { Status drives bookability: only "available" can be booked. "delayed" and "on time" cannot be booked; "flying" has taken off. If the user wants to change or cancel after a delay, follow the modify/cancel rules rather than rebooking a cancelled flight. }

std/guide:add(transfer-to-human-agents -> ok) { Transfer only when the request cannot be handled within your actions (for example, part of a trip already flown, or a passenger-count change). The summary must state the confirmed facts; say the transfer sentence next. }

std/guide:add(send-certificate -> ok) { Compensation is a gesture only, after confirming the facts: $100 x passengers for a cancelled flight, $50 x passengers for a delayed flight the user changed or cancelled. Never offer it to a regular member flying basic economy with no insurance; never offer it unprompted for other reasons. }

std/guide:add(* -> error) { A tool call failed. Read the error payload words before acting: a policy refusal needs a corrected plan, a missing record needs the exact user id, and an infrastructure error is not the user fault. Do not repeat the identical call — change the argument that caused the failure. }

std/guide:add(say -> error) { Inside say text, {{ x.f }} resolves one level into the record bound to x — {{ x.f.g }} always refuses; splice {{ x.f }} for a nested object. A bare word, number, or id is a scalar — splice it as {{ x }}, never {{ x.f }}. carries-no-field means shorten the path to one level; not-bound means bind x first. Resend the say; the call that produced x already answered, do not re-run it. }
