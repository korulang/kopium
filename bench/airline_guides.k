// airline_guides.k — the airline domain's doctrine table for the
// NATIVE protocol (native_protocol.k / native_protocol.kz).
//
// Keys are `tor` for facts true of every dispatch, and
// `tor -> branch` for what one resolved outcome means / where it goes.
// Branch names are the protocol's named states — a guide can only fire
// where the protocol declares the state.
//
// Handles: found-set/chosen-flight/user-known/reservation-known are typed
// borrows carrying "quoted" JSON content; held is the pending
// booking commitment. Pass handles by binding name where a phantom is
// demanded — never their contents, never a literal.
//
// Provenance: field truth from the corpus-mined payload shapes and
// tau2 policy; workflow frames counted from the train-30 corpus;
// branch-keyed doctrine authored in bench/guides/*.md (this table is
// the compiled, slot-free delivery of the same teaching).

import std/guide

// ============================================================================
// FIELD TRUTH — what each verb takes and what its payload carries.
// ============================================================================

std/guide:add(say) { The voice channel — the only text the user hears. Always "quoted"; {{ x.f }} inside splices one level into the record bound to x. A bare word or id is a scalar — splice it as {{ x }}, never {{ x.f }}. }

std/guide:add(get-user-details) { Takes user_id. The profile returns a user-known handle whose content is JSON: user_id, name, email, dob, address, membership (regular|silver|gold), reservations (list of reservation ids), saved_passengers, and payment_methods as an OBJECT keyed by payment id. The payment ids are the KEYS of payment_methods — there is no top-level list. Wire templates lift ONE level only: render a nested object whole, never a deeper path. }

std/guide:add(get-reservation-details) { Takes reservation_id. A reservation-known handle comes back: reservation_id, user_id, origin, destination, flight_type, cabin, flights (list of flight_number/date/origin/destination/price fields), passengers, payment_history, total_baggages, nonfree_baggages, insurance, created_at, status. Wire templates lift ONE level only — render {{ r.flights }} for the list, never a deeper path. If you lack an id, read the the user reservations list from their user-known handle or ask — never pass a placeholder. }

std/guide:add(search-direct-flight) { Takes origin, destination, date (IATA codes, YYYY-MM-DD). `results` mints a found-set handle — a SET, content is a JSON array of flight objects each {flight_number, origin, destination, date, status, available_seats, prices}. Choose by prices.<cabin>; only status "available" can be booked. `none` means no flights matched — widen dates or try onestop. }

std/guide:add(search-onestop-flight) { Same args as search-direct-flight. Each result is an ORDERED LIST of legs — every leg flight_number and date goes into the booking, in order. }

std/guide:add(select) { Borrows a found-set handle — pass the BINDING NAME the results arm issued, never flight data — and validates flight_number + date AGAINST its content — `chosen` mints a chosen-flight handle carrying the single selected flight. `miss` means the pair is not in that set: the set may be stale (a newer search retires it) or the number wrong — read the found-set content for exact flight_numbers, or search again. }

std/guide:add(hold) { user and flights take BINDING NAMES of live user-known/chosen handles (rN), never contents. Eleven args prepare book_reservation WITHOUT spending: user (user-known), flights (chosen-flight), passengers ("quoted" JSON array of first_name/last_name/dob fields), payment_id (ONE key of the the user record payment_methods object — never invented), amount, cabin, flight_type, total_baggages, nonfree_baggages, insurance. `held` mints the held obligation — nothing is booked yet. `payment-failed` = the env rejected the payment id: re-read the valid ids from the user handle payment_methods keys. `refused` = args or policy refused the hold. }

std/guide:add(release) { Spends a held obligation free — pass the BINDING NAME of the live held handle (rN), never a literal. — abandons the pending booking. The ONLY safe exit for a hold you cannot confirm; hang-up does this automatically, but releasing deliberately is cleaner. }

std/guide:add(confirm) { Spends the held obligation — pass the BINDING NAME of the live held handle (rN), never a literal. INTO book_reservation — the one commit. `booked` returns a reservation-known handle: confirm itinerary, total, and payment split to the user. `declined` = payment refused at commit; `unavailable` = fare or seat gone since the hold. Both mean the hold is spent — start over with a fresh search/select/hold if the user still wants it. }

std/guide:add(cancel-reservation) { Borrows a reservation-known handle — pass the BINDING NAME the minting arm issued (r6, r7, ...), never the reservation_id string inside it; the env-vended id comes out of the handle, so a literal is a wire refusal. `cancelled` = done; tell the user refunds return to the original payment methods in 5-7 business days. `ineligible` = policy refuses (the API does NOT check the rules for you — verify before calling: booked within 24h, airline cancelled a flight, business cabin, or insurance covering the reason, and no segment flown). `already-cancelled` = nothing to do. }

std/guide:add(update-reservation-flights) { Borrows the reservation handle — pass its BINDING NAME (rN), never the id string; takes flights (chosen-flight — select first), cabin, payment_id. Origin, destination, and flight_type must stay unchanged; cabin must match on every flight. `updated` returns the reservation; `payment-failed`/`refused` name the fix. Basic economy cannot change flights. }

std/guide:add(update-reservation-baggages) { Borrows the reservation handle — pass its BINDING NAME (rN), never the id string; takes total_baggages and nonfree_baggages as new ABSOLUTE integers (not deltas) plus payment_id. Bags can be added but never removed; each extra checked bag is 50 dollars — state the charge. Insurance cannot be added after booking. }

std/guide:add(update-reservation-passengers) { Borrows the reservation handle — pass its BINDING NAME (rN), never the id string; takes passengers ("quoted" JSON array, same count — the number cannot change). Supply the full new list. }

std/guide:add(send-certificate) { Takes user — the BINDING NAME of a live user-known handle (rN), never contents — and amount (integer dollars). A gesture of compensation, not a refund — issue only after confirming the complaint facts and the membership/insurance condition: $100 x passengers for a cancelled flight, $50 x passengers for a delayed flight the user changed or cancelled. Never for a regular member in basic economy with no insurance; never unprompted. `insufficient` = balance cannot cover it; `refused` = conditions unmet. }

std/guide:add(get-flight-status) { Takes flight_number and date. `reported` carries one status word: available | delayed | on time | flying. Only "available" can be booked; "flying" has taken off. `unknown` = the flight is not in the system. }

std/guide:add(calculate) { Takes expression as math text in "quotes". `value` returns the number — quote it in the say that follows rather than recomputing by hand. `invalid` = the expression did not parse. }

std/guide:add(list-all-airports) { `airports` returns iata/city pairs — use the iata code in every origin/destination argument, never the city name. }

std/guide:add(transfer-to-human-agents) { Takes summary (one line of confirmed facts). `handed-off` ENDS the exchange: after the call, send exactly "YOU ARE BEING TRANSFERRED TO A HUMAN AGENT. PLEASE HOLD ON." — nothing written after reaches the user. Transfer only when the request cannot be handled within your actions. }

// ============================================================================
// BRANCH STATES — what each named outcome means and where it goes next.
// ============================================================================

std/guide:add(get-user-details -> missing) { The id is not in the database — the user gave a wrong or invented id. Re-read the exact id they gave; never invent or normalize one. If they cannot produce it, ask. `missing` is a state, not an error: resolve the id, then retry. }

std/guide:add(get-reservation-details -> missing) { The reservation id is wrong or invented — never pass a placeholder. Get the real id from the the user record reservations list (get-user-details) or ask the user for the confirmation number, then retry. }

std/guide:add(search-direct-flight -> none) { No flights matched. Check the date format and IATA codes; widen the date or try search-onestop-flight before telling the user nothing exists. }

std/guide:add(search-onestop-flight -> none) { No one-stop itineraries either. The route or date may not be served — confirm the cities with the user before declaring no service. }

std/guide:add(select -> miss) { The flight_number/date pair is not in the found-set set — the set may be stale (a newer search retires it) or the number wrong. Read the exact flight_numbers in the found-set handle content, or search again. Never fabricate a selection. }

std/guide:add(hold -> payment-failed) { That payment_id is not one of this the user payment methods. The valid ids are the KEYS of payment_methods on the user-known handle content — read them there, or ask the user which method to use, then hold again. Never invent a payment id. }

std/guide:add(hold -> refused) { The hold was refused on args or policy — read the payload for which condition failed, fix that argument, and hold again. The hold spends nothing; retrying is safe. }

std/guide:add(confirm -> declined) { The payment was declined at commit — the held args carried a payment_id the env rejected. The hold is SPENT: release is not needed, but the booking did not happen. Re-check the payment id against the the user record payment_methods keys and run hold → confirm again if the user still wants it. }

std/guide:add(confirm -> unavailable) { The fare or seat disappeared between hold and commit — the hold is spent and nothing was booked. Search again for current availability, then hold → confirm fresh. Do not retry confirm on the spent hold. }

std/guide:add(cancel-reservation -> ineligible) { Policy refuses this cancellation — the API does NOT check the rules, you must. Eligible only when: booked within the last 24h, the airline cancelled a flight, cabin is business, or travel insurance covers the reason — AND no segment has flown. If none holds, transfer-to-human-agents rather than force it. }

std/guide:add(cancel-reservation -> already-cancelled) { Already cancelled — nothing to do. Confirm the state to the user and stop; do not retry the call. }

std/guide:add(update-reservation-flights -> payment-failed) { The payment_id is not a valid method on the user record — re-read the payment_methods keys from the user-known handle and retry with a real id. }

std/guide:add(update-reservation-flights -> refused) { The change was refused — likely itinerary rules (basic economy cannot change flights; origin, destination, and trip type must not change) or payment coverage. Read the payload, fix the cause, retry. }

std/guide:add(update-reservation-baggages -> payment-failed) { Same as flights: the payment_id must be a real key of the the user record payment_methods. }

std/guide:add(update-reservation-baggages -> refused) { Baggage update refused — check the allowance math and that bags are only added, never removed. }

std/guide:add(update-reservation-passengers -> refused) { Passenger update refused — the count cannot change; supply the full list with the same count. }

std/guide:add(send-certificate -> insufficient) { The balance cannot cover the amount — reduce it or explain the limit to the user. Do not retry with the same amount. }

std/guide:add(send-certificate -> refused) { The compensation conditions are unmet — re-check the facts (cancelled vs delayed flight, membership tier, cabin, insurance) before offering again. }

std/guide:add(calculate -> invalid) { The expression did not parse — check operator spelling and that numbers are plain digits; quote the corrected expression and retry. }

std/guide:add(get-flight-status -> unknown) { That flight number/date is not in the system — re-check the spelling with the user; do not guess a status. }

// ============================================================================
// RESIDUAL ERROR — transport/environment failure only.
// ============================================================================

std/guide:add(* -> error) { A call failed at the transport or environment layer — not a domain outcome. Do not repeat the identical call; if the user is waiting, say so honestly or transfer. }
