// db_scope.k — the sqlite agent surface: which of libs/sqlite3's tors the
// agent may call, under which wire names, at which costs. Moved out of
// probe_collect.k so every program that wants the `db` scope — probe,
// wire_repl, tau-agent — compiles the SAME declaration. Vocabulary drift
// between surfaces is the failure this file exists to prevent.
//
// `open-db` mints a *Connection token; `rows` turns it into a *Statement
// stream the agent steps with `next-row` and returns with `finish-stmt` or
// by stepping to `done`; `close-db` discharges the conn for good. The
// custody preamble in the grammar render teaches this — the register
// IS that preamble.

import std/runtime
import libs/sqlite3

// The voice channel — same sayIO routing as airline/airline-native: a say
// line reaches the user (or the bench driver) and owes a reply. Every
// agent scope carries a voice: the grammar preamble promises
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

// Layered scopes: leaves price the verbs, `db` composes them. A read-only
// surface is db-core + db-read; adding sql(10) is the write grant.
// (The module glob was retired: it also swept [norun]/transform decls
// that can't dispatch, so the alias set spells the dispatchable surface
// explicitly.)
std/runtime:register(scope: "db-core") {
    say(1)
    libs.sqlite3:open -> open-db(1)
    libs.sqlite3:close -> close-db(1)
}

std/runtime:register(scope: "db-read") {
    libs.sqlite3:rows -> rows(10)
    libs.sqlite3:next -> next-row(1)
    libs.sqlite3:scol.int -> col-int(1)
    libs.sqlite3:scol.text -> col-text(1)
    libs.sqlite3:scol.real -> col-real(1)
    libs.sqlite3:finalize.stmt -> finish-stmt(1)
}

std/runtime:register(scope: "db") {
    scope(db-core)
    scope(db-read)
    libs.sqlite3:exec -> sql(10)
}
