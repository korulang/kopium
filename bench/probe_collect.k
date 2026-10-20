// probe_collect.k — zero-model proof that the `db` scope (app/db_scope,
// shared with wire_repl and tau-agent) collects an imported library's tors
// into an agent-facing vocabulary: aliases give the verbs agent-readable
// wire names with their own costs, and the bridge renders what the model
// would see.

import std/io
import std/bridge
import libs/sqlite3
import app/db_scope
import app/tau_wire

// The `db` scopes live in app/db_scope now — one declaration shared by this
// probe, wire_repl, and tau-agent, so the surface under test is the surface
// the agent gets. `app/tau_wire` is not dead weight: `item-cap` below is
// the same turn guard wire_repl and tau-agent apply ahead of `run`, and
// the call is also the graph edge that keeps the module's zig alive for
// db_scope's `say` proc (sayIO lives there — an unused import would be
// stripped and the proc's `@import("root")` path would dangle).

// Drive the scope end to end: open mints a *Connection, sql borrows it by
// its token, close-db discharges it. The report names what happened.
tor drive { br: *std/bridge:Bridge<session> }
drive = app/tau_wire:item-cap(source: "open-db(path: \"probe_collect.db\") | db c |>\nsql(conn: c, sql: \"CREATE TABLE probe (id INTEGER, name TEXT)\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (1, 'a')\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (2, 'b')\") | ok _ |>\nrows(conn: c, sql: \"SELECT id, name FROM probe ORDER BY id\") | row s |>\ncol-int(stmt: s, index: 0) | ok i |>\ncol-text(stmt: s, index: 1) | ok n |>\nnext-row(stmt: s) | row s2 |>\ncol-int(stmt: s2, index: 0) | ok i2 |>\nnext-row(stmt: s2) | done d |>\nrows(conn: d, sql: \"SELECT id FROM probe\") | row s3 |>\nfinish-stmt(stmt: s3) | ok c2 |>\ncol-int(stmt: s3, index: 0) | ok stale |>\nclose-db(conn: c2) | ok _ |>", max: 128)
| ok _ |> std/bridge:run(br, source: "open-db(path: \"probe_collect.db\") | db c |>\nsql(conn: c, sql: \"CREATE TABLE probe (id INTEGER, name TEXT)\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (1, 'a')\") | ok _ |>\nsql(conn: c, sql: \"INSERT INTO probe VALUES (2, 'b')\") | ok _ |>\nrows(conn: c, sql: \"SELECT id, name FROM probe ORDER BY id\") | row s |>\ncol-int(stmt: s, index: 0) | ok i |>\ncol-text(stmt: s, index: 1) | ok n |>\nnext-row(stmt: s) | row s2 |>\ncol-int(stmt: s2, index: 0) | ok i2 |>\nnext-row(stmt: s2) | done d |>\nrows(conn: d, sql: \"SELECT id FROM probe\") | row s3 |>\nfinish-stmt(stmt: s3) | ok c2 |>\ncol-int(stmt: s3, index: 0) | ok stale |>\nclose-db(conn: c2) | ok _ |>")
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
| over n |> std/io:print.ln("RUN OVER-CAP: {{ n:d }} items")

[with]std/bridge:create(id: "probe", scope: "db", introspection: true, world: ""): br
|> std/bridge:grammar(br)
| ok g |> std/io:print.ln("{{ g:s }}") |> drive(br)
| not-found m |> std/io:eprint.ln("grammar render failed: {{ m:s }}")
