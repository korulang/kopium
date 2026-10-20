// probe_cells — a parent program spawning a db-scoped child cell.
//
// The question: can the fleet/cell substrate carry a vocabulary-scoped
// sub-agent that shares a world with its parent — custody visible to the
// parent afterward? Spawned under scope "db", the child's own bridge holds
// its handles; its world slice is cells/child-1/, where holds.log witnesses
// every mint/release. The parent reads that log through std/fs — the
// inspection is ordinary file access, not special machinery.

import std/io
import std/fs
import std/fleet
import std/cell
import std/proto
import app/db_scope

std/proto(child_state) { turns: u32 }

std/fleet:new(node, scope: "db", world: "cells", capacity: 4)

std/fleet(node)
| fleet f |> std/fleet:spawn(f, id: "child-1", cell: child_state)
  | spawned b |> std/io:print.ln("spawned child-1")
  | resident |> std/io:print.ln("child-1 already resident")
  | refused |> std/io:print.ln("spawn refused")

// turn 1 — the child mints a connection on ITS bridge; r1 survives to turn 2
std/fleet(node.child-1)
| cell b |> std/cell:run(c: b, source: "open-db(path: \"cells_probe.db\") | db c |>\nsql(conn: c, sql: \"CREATE TABLE pets(id INTEGER, name TEXT)\")")
  | result r |> std/io:print.ln("child turn1 result: {{ r.bound:s }}")
  | partial p |> std/io:print.ln("child turn1 partial {{ p.ran:d }}/{{ p.total:d }}\n{{ p.report:s }}")
  | error e |> std/io:print.ln("child turn1 {{ e.kind:s }}: {{ e.message:s }}")
  | unhandled-branch ub |> std/io:print.ln("child turn1 unhandled {{ ub.branch:s }}")
  | residue x |> std/io:print.ln("child turn1 residue")
  | defined d |> std/io:print.ln("child turn1 defined {{ d:s }}")
| not-found |> std/io:print.ln("child-1 missing")

// turn 2 — cross-run custody: conn: r1 names the handle minted above
std/fleet(node.child-1)
| cell b |> std/cell:run(c: b, source: "sql(conn: r1, sql: \"INSERT INTO pets VALUES (1, 'Rex')\")\nsay(text: \"child wrote a pet\")\nclose-db(conn: r1)")
  | result r |> std/io:print.ln("child turn2 result: {{ r.bound:s }}")
  | partial p |> std/io:print.ln("child turn2 partial {{ p.ran:d }}/{{ p.total:d }}\n{{ p.report:s }}")
  | error e |> std/io:print.ln("child turn2 {{ e.kind:s }}: {{ e.message:s }}")
  | unhandled-branch ub |> std/io:print.ln("child turn2 unhandled {{ ub.branch:s }}")
  | residue x |> std/io:print.ln("child turn2 residue")
  | defined d |> std/io:print.ln("child turn2 defined {{ d:s }}")
| not-found |> std/io:print.ln("child-1 missing")

// the parent's look: the child's world slice tells what it held and released
std/fs:read-lines(path: "cells/child-1/holds.log")
! line l |> std/io:print.ln("holds: {{ l:s }}")
| done n |> std/io:print.ln("— {{ n:d }} custody event(s)")
| failed f |> std/io:print.ln("holds.log unread: {{ f:s }}")

// drain — every resident cell hibernates through the discharge path
std/fleet(node)
| fleet f |> std/fleet:drain(f): n |> std/io:print.ln("drained {{ n:d }} cell(s)")
