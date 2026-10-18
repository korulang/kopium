// Offline check: the bytes `ask` splices in as the system message, plus the
// growth proof — define a flow through the gate, re-render the grammar, and
// the new verb must appear in the block (what the per-ask re-render in
// tau-agent.k gives the model for free). No model, no keys, no spend.

import std/io
import std/bridge
import app/airline_tools
import app/airline_native
import app/corpus_env
import app/tau_wire
import koru/yyjson
import koru/sse
import koru/curl

koru/yyjson:parse(text: "{}")
| ok doc |> koru/yyjson:close(doc)
| err _ |> _

app/tau_wire:scope-name(): sc
|> [with]std/bridge:create(id: "probe-sysblock", scope: sc, introspection: true, world: ""): br
|> std/bridge:grammar(br)
| ok g |> std/io:print.ln("===== SYSTEM BLOCK (before define) =====")
    |> std/io:print.ln("{{ g:s }}")
    |> std/io:print.ln("===== END =====")
    |> std/io:print.ln("===== DEFINE, THEN RE-RENDER =====")
    |> std/bridge:run(br, source: "tor probe-verb { x: string }\nprobe-verb = std/io:print.ln(\"{{ x:s }}\")")
        | defined d2 |> std/io:print.ln("  defined: {{ d2:s }}")
            |> std/bridge:grammar(br)
            | ok g2 |> std/io:print.ln("===== SYSTEM BLOCK (after define) =====")
                |> std/io:print.ln("{{ g2:s }}")
            | not-found s3 |> std/io:print.ln("grammar not-found after define: {{ s3:s }}")
        | result r2 |> std/io:print.ln("  unexpected result")
        | partial p2 |> std/io:print.ln("  partial: {{ p2.report:s }}")
        | parse-error p2 |> std/io:print.ln("  DEFINE PARSE-ERROR: {{ p2.message:s }}")
        | unhandled-branch ub2 |> std/io:print.ln("  unhandled-branch: {{ ub2.branch:s }}")
        | validation-error v2 |> std/io:print.ln("  validation-error: {{ v2:s }}")
        | shape-error sh2 |> std/io:print.ln("  shape-error: {{ sh2.message:s }}")
        | event-denied ev2 |> std/io:print.ln("  event-denied: {{ ev2:s }}")
        | dispatch-error e2 |> std/io:print.ln("  dispatch-error: {{ e2.message:s }}")
        | exhausted e2 |> std/io:print.ln("  exhausted: {{ e2.last_event:s }}")
        | residue r2 |> std/io:print.ln("  residue: {{ r2.report:s }}")
        | scope-not-found s4 |> std/io:print.ln("  scope-not-found: {{ s4:s }}")
| not-found s |> std/io:eprint.ln("grammar not-found: {{ s:s }}")
