// db_scope.k — the bench world's "db" scope: the shared sqlite verbs
// (headless/db_verbs — wire names every world agrees on) plus this
// world's voice. The bench's say rides sayIO: a say line reaches the
// wire protocol (wire_repl / tau-agent / the drivers) and owes a reply.
// Headless prints its own say to stderr — the verb set is identical,
// the channel is each world's own.

import std/runtime
import headless/db_verbs

// Every agent scope carries a voice: the grammar preamble promises
// `say(text: "...")` is what reaches the user, and without this verb in
// the register that sentence is a lie the wall would deny.
[
- doc
Delivers text to the user — the only verb they can hear. Owes them a reply.
]
pub tor say { text: string } -> string

proc say|zig {
    return @import("root").koru_app.koru_tau_wire.sayIO(text);
}

std/runtime:register(scope: "db") {
    scope(db-verbs)
    say(1)
}
