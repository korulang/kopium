// probe_collect.k — zero-model proof that a register block collects an
// imported library's tors into an agent-facing vocabulary. No marshal,
// no hand-written decls: the scope globs libs/sqlite3, aliases two verbs
// to agent-readable names with their own costs, and the bridge renders
// what the model would see.

import std/io
import std/bridge
import libs/sqlite3

// Imported tors register under their logical (dotted) module name —
// `libs/sqlite3` materializes as `libs.sqlite3`, so the glob and alias
// sources spell it that way. The wire-facing name is the alias.
// Aliases give the agent bare, callable names with declared costs —
// reads cheap, writes dear. (The module glob currently also sweeps
// [norun]/transform decls that can't dispatch — collector gap, so the
// alias set spells the dispatchable surface explicitly.)
// Layered scope: leaves price the verbs, `db` composes them. A read-only
// surface is db-core + db-read; adding sql(10) is the write grant.
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

std/runtime:register(scope: "db") {
    scope(db-core)
    scope(db-read)
    libs.sqlite3:exec -> sql(10)
}

// Drive the scope end to end: open mints a *Connection, sql borrows it by
// its token, close-db discharges it. The report names what happened.
tor drive { br: *std/bridge:Bridge<session> }
drive = std/bridge:run(br, source: "open-db(path: \"probe_collect.db\") | db c |>\nsql(conn: c, sql: \"CREATE TABLE probe (id INTEGER, name TEXT)\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (1, 'a')\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (2, 'b')\") | ok _ |>\nrows(conn: c, sql: \"SELECT id, name FROM probe ORDER BY id\") | row s |>\ncol-int(stmt: s, index: 0) | ok i |>\ncol-text(stmt: s, index: 1) | ok n |>\nnext-row(stmt: s) | row s2 |>\ncol-int(stmt: s2, index: 0) | ok i2 |>\nnext-row(stmt: s2) | done d |>\nrows(conn: d, sql: \"SELECT id FROM probe\") | row s3 |>\nfinish-stmt(stmt: s3) | ok c2 |>\ncol-int(stmt: s3, index: 0) | ok stale |>\nclose-db(conn: c2) | ok _ |>")
| result r |> std/io:print.ln("RUN RESULT bound={{ r.bound:s }}\n{{ r.trace:s }}")
| partial p |> std/io:print.ln("RUN PARTIAL: {{ p.report:s }}")
| unhandled-branch u |> std/io:print.ln("RUN UNHANDLED: {{ u.branch:s }} — {{ u.payload:s }} (held {{ u.handles:s }})")
| parse-error p |> std/io:print.ln("RUN PARSE: {{ p.message:s }}")
| event-denied e |> std/io:print.ln("RUN DENIED: {{ e:s }}")
| defined d |> std/io:print.ln("RUN DEFINED: {{ d:s }}")
| exhausted x |> std/io:print.ln("RUN EXHAUSTED at {{ x.last_event:s }}")
| validation-error v |> std/io:print.ln("RUN VALIDATION: {{ v:s }}")
| shape-error s |> std/io:print.ln("RUN SHAPE: {{ s.message:s }}")
| dispatch-error de |> std/io:print.ln("RUN DISPATCH {{ de.event_name:s }}: {{ de.message:s }}\n{{ de.trace:s }}")
| scope-not-found sn |> std/io:print.ln("RUN NO-SCOPE: {{ sn:s }}")
| residue _ |> std/io:print.ln("RUN RESIDUE")

[with]std/bridge:create(id: "probe", scope: "db", introspection: true, world: ""): br
|> std/bridge:grammar(br)
| ok g |> std/io:print.ln("{{ g:s }}") |> drive(br)
| not-found m |> std/io:eprint.ln("grammar render failed: {{ m:s }}")
