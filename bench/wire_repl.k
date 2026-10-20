// wire_repl.k — the tau-agent surface with a human where the model sits.
// Same register block, same bridge, same gate; the model call is replaced
// by stdin. Whoever drives this binary experiences the wire exactly as the
// model does: programs go in as {"kind":"wire","text":...}, the report the
// model would have observed comes back as {"kind":"report","text":...},
// and say/call ride the same outbound lines they do in the bench.
//
//   in : {"kind":"init","policy":...} once, then {"kind":"wire",...} /
//        {"kind":"user",...} / {"kind":"result",...}
//   out: {"kind":"grammar",...} once at boot, then say/call (mid-run),
//        report (turn verdict), heard (pended user lines), ready (turn end)
//
//   koruc build wire_repl.k → a.out is the REPL binary.
//   bench/wire_driver.py is the marshal: it plays the tau2 environment
//   for `call` lines and hands stdin/stdout to a human.

import std/io
import std/fmt
import std/bridge
import std/interpreter
import app/airline_tools
import app/airline_native
import app/corpus_env
import app/tau_wire
import app/db_scope
import koru/yyjson

// Run a program through the gate and emit the report text — the same
// strings tau-agent's `act` observes into the transcript, minus the
// transcript and the session counters (there is no model to show them to).
tor report-run { br: *std/bridge:Bridge<session>, source: string<*> }
report-run = app/tau_wire:item-cap(source, max: 128)
| ok _ |> std/bridge:run(br, source)
    | result r |> std/interpreter:value.stringify(r.value): v
        |> std/fmt:fmt.blk {
            {{ r.trace:s }}result: {{ v:s }} bound: {{ r.bound:s }}
        }: m |> app/tau_wire:emit(kind: "report", text: m)
    | defined d |> std/fmt:fmt.blk {
        defined: {{ d:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | partial p |> app/tau_wire:emit(kind: "report", text: p.report)
    | unhandled-branch ub |> std/fmt:fmt.blk {
        unhandled-branch: {{ ub.branch:s }} — {{ ub.payload:s }} (held {{ ub.handles:s }}). An arm word must be a branch name — `ok` binds an ordinary result, a named branch binds under its own name; no other arm word matches.
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | dispatch-error e |> std/fmt:fmt.blk {
        {{ e.trace:s }}dispatch-error {{ e.event_name:s }}: {{ e.message:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | event-denied ev |> std/fmt:fmt.blk {
        event-denied: {{ ev:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | residue r |> app/tau_wire:emit(kind: "report", text: r.report)
    | parse-error p |> std/fmt:fmt.blk {
        parse-error: {{ p.message:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | validation-error v |> std/fmt:fmt.blk {
        validation-error: {{ v:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | shape-error sh |> std/fmt:fmt.blk {
        shape-error {{ sh.branch:s }}: {{ sh.message:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | exhausted e |> std/fmt:fmt.blk {
        exhausted: {{ e.last_event:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
    | scope-not-found s2 |> std/fmt:fmt.blk {
        scope-not-found: {{ s2:s }}
    }: m |> app/tau_wire:emit(kind: "report", text: m)
| over _ |> app/tau_wire:emit(kind: "report", text: "exhausted: turn item cap exceeded")

// User replies captured by say() procs while pull() collected them —
// surfaced so the driver can show the human what the "user" said back.
tor drain-heard {}
| again
| done

drain-heard = app/tau_wire:take-pending()
| some u |> app/tau_wire:emit(kind: "heard", text: u) |> drain-heard()
    | again => again
    | done => done
| none |> app/tau_wire:saw-eof()
    | yes => done
    | no => again

// Turn end: pull() collects the user replies owed by this turn's says
// (it blocks reading exactly `outstanding` lines — a say owed a reply is
// a pull target, so the driver must send them before the next program),
// drain the pend queue, then mark the turn complete.
tor finish-turn { br: *std/bridge:Bridge<session> }
finish-turn = app/tau_wire:pull() |> drain-heard()
| again |> app/tau_wire:emit(kind: "ready", text: "") |> turn(br)
| done |> app/tau_wire:emit(kind: "ready", text: "") |> turn(br)

tor turn { br: *std/bridge:Bridge<session> }
turn = app/tau_wire:inbound()
| wire w |> report-run(br, source: w) |> finish-turn(br)
| user u |> app/tau_wire:emit(kind: "heard", text: u) |> turn(br)
| init _ | app/tau_wire:die(msg: "init line after boot")
| result _ | app/tau_wire:die(msg: "result with no outstanding call")
| eof |> _
| bad m |> app/tau_wire:emit(kind: "bad", text: m) |> turn(br)

// Boot: the system surface the model would see — rendered once, emitted
// verbatim, so the human reads the same grammar before typing a program.
tor repl-boot { br: *std/bridge:Bridge<session> }
repl-boot = std/bridge:grammar(br)
| ok g |> app/tau_wire:emit(kind: "grammar", text: g) |> app/tau_wire:inbound()
    | init _ |> app/tau_wire:emit(kind: "ready", text: "") |> turn(br)
    | wire _ | app/tau_wire:die(msg: "wire before init")
    | user _ | app/tau_wire:die(msg: "user before init")
    | result _ | app/tau_wire:die(msg: "result with no outstanding call")
    | eof |> _
    | bad m |> app/tau_wire:die(msg: m)
| not-found m |> app/tau_wire:die(msg: m)

app/tau_wire:scope-name(): sc
|> app/corpus_env:env-or(key: "KOPIUM_WORLD", fallback: ""): w
|> [with]std/bridge:create(id: "wire-repl", scope: sc, introspection: true, world: w): br
|> koru/yyjson:parse(text: "{}")
    | ok d |> koru/yyjson:close(doc: d) |> repl-boot(br)
    | err _ |> repl-boot(br)
