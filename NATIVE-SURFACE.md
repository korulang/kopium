# NATIVE-TOOLS — the hand-written Koru tool surface

Status: design spec, proposed 2026-11-12. Supersedes the generated
`airline_tools.k` transliteration as the agent-facing contract.

## The problem this fixes

`gen_airline.kz` compiles tau2's JSON function-calling schemas into Koru
tors whose procs call `callIO` and return **raw JSON strings**. The model
then programs against untyped text: `{{ u.name.first_name }}` fails at
dispatch, composite args are hand-serialized JSON strings, obligations
like read-before-cancel are enforced by string-matching session state.
Every failure class chased on 2026-11-12 (nested template paths,
placeholder args, unbound bindings, malformed composites) is a symptom
of a transliterated boundary — teaching cannot fix an untyped surface.

## Design laws

1. **Hand-written, not generated.** The surface is Koru source,
   diffable, obligation-annotated. tau2's schema remains the
   *transport contract* beneath `callIO`; the *agent contract* is ours.
2. **Typed values cross the boundary.** Results parse once into Koru
   records/lists at the `callIO` seam; the model binds structure, never
   JSON text. `{{ }}` template splicing dies with the string results.
3. **Obligations are type-state.** Mutating verbs demand handles the
   type system minted: `*Reservation<verified!>` can feed
   `cancel-reservation`; `*Reservation<unverified>` cannot. The illegal
   call is uncompilable, not refused-at-runtime.
4. **Progressive disclosure is structural.** Lookup verbs carry summary
   projections; deep fields and mutation arg-shapes disclose at the
   workflow point (the existing `std/guide` channel already fires
   per `(tor, branch)` — arg-shape teaching rides it).
5. **tau2 stays the state oracle.** We do not reimplement the airline
   DB. `callIO` remains transport; tau2's env validates and mutates.
   Koru owns the surface semantics: types, obligations, disclosure.

## The surface

Notation: `name(args) -> result` with Koru record types; `*T<state!>`
marks obligation-carrying handles; `! discharge` settles on consume.

### Reads (cost 1) — disclose first

```
get-user-details(user_id: string)
    -> User { user_id, name: PersonName, email, dob,
              address: Address, membership: Membership,
              reservations: [ReservationRef], saved_passengers: [Person] }

get-reservation-details(reservation_id: string)
    -> *Reservation<unverified!> { reservation_id, user_id, origin,
        destination, flight_type, cabin, status,
        flights: [FlightLeg], passengers: [Person],
        payment_history: [PaymentRecord], totals: BaggageCounts,
        insurance, created_at }
    // unverified: read-only. Mutations require <verified>.

get-flight-status(flight_number: string, date: Date)
    -> FlightStatus { flight_number, date, origin, destination,
                      status, available_seats: SeatMap, prices: FareMap }

search-direct-flight(origin: Iata, destination: Iata, date: Date)
    -> [FlightOption]   // each { flight_number, date, status,
                         //   available_seats, prices }

search-onestop-flight(origin: Iata, destination: Iata, date: Date)
    -> [[FlightLeg]]    // ordered leg lists, not flat flights

list-all-airports() -> [Airport] { code, city, name }
```

### Verification step — the obligation mint

```
verify-reservation(r: *Reservation<unverified!>)
    -> *Reservation<verified!>
// Explicit confirmation step: the model must look at the reservation
// and attest it matches the user's intent before mutations unlock.
// Cheap, honest, and it makes "did you check?" a type question.
```

### Mutations (cost 10) — demand verified handles

```
cancel-reservation(r: *Reservation<verified!>, reason?: string)
    -> *Reservation<cancelled!>

update-reservation-flights(r: *Reservation<verified!>,
    cabin: Cabin, flights: [FlightLeg], payment: PaymentRef)
    -> *Reservation<updated!>

update-reservation-baggages(r: *Reservation<verified!>,
    total: i64, nonfree: i64, payment: PaymentRef)
    -> *Reservation<updated!>

update-reservation-passengers(r: *Reservation<verified!>,
    passengers: [Person]) -> *Reservation<updated!>

book-reservation(profile: *User<known!>, itinerary: Itinerary,
    passengers: [Person], payment: PaymentRef,
    bags: BaggageCounts, insurance: Insurance)
    -> *Reservation<booked!>
```

### Session verbs

```
say(text: string) -> Delivered          // the only user-facing verb
note(text: string)                      // observer-only reasoning
abandon(reason: string)                 // ends session with account
transfer-to-human-agents(summary: string)
send-certificate(user_id: string, amount: Money)
calculate(expression: string) -> number // stays string-in, typed-out
```

## Progressive disclosure mechanics

- `vocabulary()` renders **verbs only** — signatures stay one line.
- Full arg shapes + record fields disclose via `std/guide` rows keyed
  `(tor, branch)` — already the firing mechanism; mutation verbs'
  composite shapes (flights/passengers/payment) teach at first
  approach, not boot.
- `get-reservation-details` returns the summary projection; flight
  legs, passengers, payment_history deep-dive on a follow-up verb or
  guide-disclosed accessor — context scales with workflow depth.
- The `contract` doc becomes per-branch: ok-branch doc shows the
  record shape; error-branch doc shows failure modes.

## What dies with the transliteration

- `{{ }}` template splicing on JSON strings (typed bindings replace it)
- Hand-serialized composite JSON args (`flights="[{...}]"`)
- Placeholder/meta-word args (typed fields + obligation flow make
  invented values structurally obvious — and the placeholder guard
  becomes a type error, not a heuristic)
- String-matched enforcement (read-before-cancel → obligation)
- The generated-file drift problem (hand-written source IS the
  contract; tau2 schema changes surface as transport mismatches,
  loud)

## Migration path

1. `airline_native.kz` already exists as a stub — grow it into the
   hand-written surface, one verb family at a time (reads first).
2. Boundary procs parse tau2 JSON → Koru values once at `callIO`
   return; args serialize Koru → JSON once at call. Transport stays.
3. Obligation handles ride the existing binding/custody machinery
   (`*T<state!>` annotations already compile).
4. Keep `airline_tools.k` generated arm as the **stock control** in
   measure.py until native wins a paired cell — the transliteration
   becomes the baseline, not the product.
5. Falsifier: same tasks 0–10, same model, paired trials. The native
   surface must beat the generated arm on collapse rate AND reward —
   or the spec is wrong and we learn that cheaply.

## Open questions

- Do obligations survive `callIO`'s string transport, or do handles
  need session-persistent mint/discharge across replies? (custody
  machinery suggests yes — verify in bridge.custody.kz)
- Progressive disclosure granularity: per-verb guide rows vs.
  field-level projection verbs (`reservation.flights` on demand)?
- `calculate` and composite JSON fields: typed Koru values or keep
  string-in/string-out for v1?
- Does the stock tau2 `LLMAgent` arm need the same surface for fair
  comparison, or is native-vs-transliteration itself the treatment?
