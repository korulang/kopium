# Tool contract — generated from the declared schema

Every entry below is translated verbatim from the tool schema the
stock interface advertises (descriptions, types, enums, nested field
shapes). An `Expression` field takes its text bare — an
array/object (`flights: [{...}]`, record keys `k: v` normalize to
JSON) or math text (`calculate(expression: 2 + 2)`) — and quotes it
when the text carries a comma, a `)`, or a newline. Scalar strings
still need "double quotes".

say(text: string) — the voice channel: what the user hears. Always
"quoted" — {{ }} inside splices bound values into the line.

book-reservation — Book a reservation.
  user_id: string — The ID of the user to book the reservation such as 'sara_doe_496'`.
  origin: string — The IATA code for the origin city such as 'SFO'.
  destination: string — The IATA code for the destination city such as 'JFK'.
  flight_type: string — one of round_trip | one_way — The type of flight such as 'one_way' or 'round_trip'.
  cabin: string — one of business | economy | basic_economy — The cabin class such as 'basic_economy', 'economy', or 'business'.
  flights: Expression — array/object, bare or "quoted"; bare record keys (k: v) normalize to JSON — {flight_number: string — Flight number, such as 'HAT001'.; date: string — The date for the flight in the format 'YYYY-MM-DD', such as '2024-05-01'.}
  passengers: Expression — array/object, bare or "quoted"; bare record keys (k: v) normalize to JSON — {first_name: string — Passenger's first name; last_name: string — Passenger's last name; dob: string — Date of birth in YYYY-MM-DD format}
  payment_methods: Expression — array/object, bare or "quoted"; bare record keys (k: v) normalize to JSON — {payment_id: string — Unique identifier for the payment; amount: integer — Payment amount in dollars}
  total_baggages: integer — The total number of baggage items to book the reservation.
  nonfree_baggages: integer — The number of non-free baggage items to book the reservation.
  insurance: string — one of yes | no — Whether the reservation has insurance.

calculate — Calculate the result of a mathematical expression.
  expression: Expression — bare math/expression text — The mathematical expression to calculate, such as '2 + 2'. The expression can contain numbers, operators (+, -, *, /), parentheses, and spaces.

cancel-reservation — Cancel the whole reservation.
  reservation_id: string — The reservation ID, such as 'ZFA04Y'.

get-flight-status — Get the status of a flight.
  flight_number: string — The flight number.
  date: string — The date of the flight.

get-reservation-details — Get the details of a reservation.
  reservation_id: string — The reservation ID, such as '8JX2WO'.

get-user-details — Get the details of a user, including their reservations.
  user_id: string — The user ID, such as 'sara_doe_496'.

list-all-airports — Returns a list of all available airports.

search-direct-flight — Search for direct flights between two cities on a specific date.
  origin: string — The origin city airport in three letters, such as 'JFK'.
  destination: string — The destination city airport in three letters, such as 'LAX'.
  date: string — The date of the flight in the format 'YYYY-MM-DD', such as '2024-01-01'.

search-onestop-flight — Search for one-stop flights between two cities on a specific date.
  origin: string — The origin city airport in three letters, such as 'JFK'.
  destination: string — The destination city airport in three letters, such as 'LAX'.
  date: string — The date of the flight in the format 'YYYY-MM-DD', such as '2024-05-01'.

send-certificate — Send a certificate to a user. Be careful!
  user_id: string — The ID of the user to book the reservation, such as 'sara_doe_496'.
  amount: integer — The amount of the certificate to send.

transfer-to-human-agents — Transfer the user to a human agent, with a summary of the user's issue.

Only transfer if
 -  the user explicitly asks for a human agent
 -  given the policy and the available tools, you cannot solve the user's issue.
  summary: string — A summary of the user's issue.

update-reservation-baggages — Update the baggage information of a reservation.
  reservation_id: string — The reservation ID, such as 'ZFA04Y'
  total_baggages: integer — The updated total number of baggage items included in the reservation.
  nonfree_baggages: integer — The updated number of non-free baggage items included in the reservation.
  payment_id: string — The payment id stored in user profile, such as 'credit_card_7815826', 'gift_card_7815826', 'certificate_7815826'.

update-reservation-flights — Update the flight information of a reservation.
  reservation_id: string — The reservation ID, such as 'ZFA04Y'.
  cabin: string — one of business | economy | basic_economy — The cabin class of the reservation
  flights: Expression — array/object, bare or "quoted"; bare record keys (k: v) normalize to JSON — {flight_number: string — Flight number, such as 'HAT001'.; date: string — The date for the flight in the format 'YYYY-MM-DD', such as '2024-05-01'.}
  payment_id: string — The payment id stored in user profile, such as 'credit_card_7815826', 'gift_card_7815826', 'certificate_7815826'.

update-reservation-passengers — Update the passenger information of a reservation.
  reservation_id: string — The reservation ID, such as 'ZFA04Y'.
  passengers: Expression — array/object, bare or "quoted"; bare record keys (k: v) normalize to JSON — {first_name: string — Passenger's first name; last_name: string — Passenger's last name; dob: string — Date of birth in YYYY-MM-DD format}

