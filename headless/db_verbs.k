// db_verbs.k — the sqlite agent surface, verb registrations only.
// These scopes are what EVERY world agrees on: the wire names, their
// signatures, their costs. What they deliberately do not carry is a
// voice — `say` is a per-world verb (headless prints to stderr, the
// bench marshal routes it as a protocol line), so each world's "db"
// scope is a composite: `scope(db-verbs)` plus its own say.
//
// `open-db` mints a *Connection token; `rows` turns it into a *Statement
// stream stepped by `next-row`, borrowed by `col-*`, and returned by
// `finish-stmt` or a `done` step; `close-db` discharges for good.
// Layered: db-core is open/close, db-read is the stream family,
// db-verbs composes them and adds the write grant.

import std/runtime
import libs/sqlite3

std/runtime:register(scope: "db-core") {
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

std/runtime:register(scope: "db-verbs") {
    scope(db-core)
    scope(db-read)
    libs.sqlite3:exec -> sql(10)
}
