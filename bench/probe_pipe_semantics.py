#!/usr/bin/env python3
"""probe_pipe_semantics.py — WIRE-GAP-ANALYSIS cell #5 probe.

Does `|>` pipe data or merely sequence? No assertions: for each case print
the wire sent, every event (kind + payload), the status/verdict detail,
and the drained call_step records. Fresh TauGateSession per case.

Binary: bench/airline-gate-binary (rebuilt vs koru 8a78f248c).
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from tau_gate_session import TauGateSession  # noqa: E402

BINARY = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "airline-gate-binary"

USER = ("mia_li_3668", '{"user_id":"mia_li_3668",'
        '"name":{"first_name":"Mia","last_name":"Li"},'
        '"email":"mia.li@example.com","membership":"gold",'
        '"reservations":["#A1234"]}')


def pump(g, wire, results, max_events=16):
    """One wire turn -> print every event until the verdict.
    `results`: list of (content, error) applied to calls in arrival order;
    last entry repeats if more calls arrive than listed."""
    print(f"  WIRE: {wire!r}")
    print(f"  FEED: {results}")
    calls = 0
    ev = g.send_wire(wire)
    while True:
        kind = ev[0]
        if kind == "call":
            obj = ev[1]
            print(f"  EVENT call: {json.dumps(obj)}")
            content, error = results[min(calls, len(results) - 1)]
            calls += 1
            ev = g.feed_result(obj.get("id"), content, error=error)
        elif kind == "say":
            print(f"  EVENT say: {json.dumps(ev[1])}")
            ev = g.next_event()
        elif kind == "status":
            print(f"  EVENT status: {ev[1]}")
            for line in str(ev[2]).split("\n"):
                print(f"      detail| {line}")
            return
        elif kind == "eof":
            print("  EVENT eof")
            return
        else:
            print(f"  EVENT {kind}: {ev[1:]}")
            return
        if calls + len([1]) > max_events:
            print("  (loop-exhausted)")
            return


def case(name, wire, results=None):
    print(f"\n===== {name} =====")
    g = TauGateSession(BINARY)
    try:
        pump(g, wire, results or [(USER[1], False)])
        # flush: CALLSTEPS for the turn is emitted AFTER its verdict and
        # parsed lazily during the next turn's reads (see gate_probe).
        try:
            pump(g, "vocabulary()\n", results or [(USER[1], False)])
        except Exception as e:
            print(f"  FLUSH-TURN {type(e).__name__}: {e}")
        recs = g.drain_callsteps()
        print(f"  CALLSTEPS ({len(recs)}):")
        for r in recs:
            print(f"      {json.dumps(r)}")
        unfr = g.drain_unframed()
        if unfr:
            print(f"  UNFRAMED ({len(unfr)}):")
            for u in unfr:
                print(f"      {u}")
    except TimeoutError as e:
        print(f"  TIMEOUT: {e}")
    except Exception as e:
        print(f"  {type(e).__name__}: {e}")
    finally:
        g.close()


ok = '{"ok":true}'

# A — bare |> after a NON-void call: does the empty-branch arm fire?
case("A: bare |> after non-void call, success result",
     f'get-user-details(user_id: "{USER[0]}") |> say(text: "x")\n',
     [(USER[1], False)])

# B — real arm word `found`: does interpolation see the bound value?
case("B: | found u |> armed, {{u.name}} interpolation",
     f'get-user-details(user_id: "{USER[0]}") | found u |> '
     'say(text: "{{u.name}}")\n',
     [(USER[1], False)])

# C — bare |> after non-void call, error result
case("C: bare |> after non-void call, error result",
     f'get-user-details(user_id: "{USER[0]}") |> say(text: "x")\n',
     [('{"error":"not found"}', True)])

# D — arm binding crossing items inside ONE turn
case("D: arm bound on item 1, read on item 2 (same turn)",
     f'get-user-details(user_id: "{USER[0]}") | found u |> say(text: "one")\n'
     'say(text: "{{u.name}}")\n',
     [(USER[1], False)])

# E — unarmed call on line 1, unbound read on line 2
case("E: unarmed call then {{u.name}} (expect not-bound teach)",
     f'get-user-details(user_id: "{USER[0]}")\n'
     'say(text: "{{u.name}}")\n',
     [(USER[1], False)])

# F1 — void-step pipe: note is the observer lane, does |> sequence it?
case("F1: note(text: a) |> say(text: b)",
     'note(text: "a") |> say(text: "b")\n',
     [(ok, False)])

# F2 — say arm binds the emitted text
case("F2: say | ok x |> say({{x}})",
     'say(text: "a") | ok x |> say(text: "{{x}}")\n',
     [(ok, False)])

print(f"\n=== done, binary={BINARY.name} ===")
