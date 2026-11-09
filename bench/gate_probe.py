#!/usr/bin/env python3
"""gate_probe.py — deterministic wire-level tests for the KOPIUM gate.

No LLM, no tau2, no orchestrator: scripted wire programs fed straight to
the gate binary via TauGateSession. This is the layer that should have
been tested algorithmically all along — every protocol bug we chased
through full simulations (status misclassification, STEPS awaiting,
empty says, malformed call JSON, multi-item hangs) is reproducible here
in seconds.

Each case: send wire -> pump events (say->feed_user, call->feed_result)
-> assert the event/status sequence. A case that hangs hits
TAU_GATE_TIMEOUT and reports TIMEOUT.

Usage: python3 gate_probe.py [binary] [--verbose]
"""

import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from tau_gate_session import TauGateSession  # noqa: E402

BINARY = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else HERE / "airline-gate-binary"
VERBOSE = "--verbose" in sys.argv
TIMEOUT = float(os.environ.get("TAU_GATE_TIMEOUT", "20"))

RESULTS = []


def pump(g, max_events=12, user_reply="ok", call_result='{"ok":true}'):
    """Feed a wire turn, answering say/call blocks until a status verdict.
    Returns list of (kind, summary) events + final status."""
    events = []
    ev = g.send_wire(CURRENT_WIRE)
    while len(events) < max_events:
        kind = ev[0]
        if kind == "call":
            obj = ev[1]
            events.append(("call", f"{obj.get('name')} {obj.get('arguments')}"))
            ev = g.feed_result(obj.get("id"), call_result, error=False)
        elif kind == "say":
            text = str(ev[1].get("text", ""))
            events.append(("say", text[:60]))
            ev = g.feed_user(user_reply)
        elif kind == "status":
            events.append(("status", f"{ev[1]} {ev[2][:80]}"))
            return events
        elif kind == "eof":
            events.append(("eof", ""))
            return events
        else:
            events.append((kind, str(ev[1])[:60] if len(ev) > 1 else ""))
            return events
    events.append(("loop-exhausted", ""))
    return events


def case(name, wire, expect_kinds, expect_status=None, user_reply="ok"):
    """Run one wire turn; assert event kinds sequence + optional status."""
    global CURRENT_WIRE
    CURRENT_WIRE = wire
    g = TauGateSession(BINARY)
    t0 = time.time()
    try:
        events = pump(g, user_reply=user_reply)
        kinds = [e[0] for e in events]
        status = next((e[1] for e in events if e[0] == "status"), None)
        ok = all(k in kinds for k in expect_kinds)
        if expect_status and status:
            ok = ok and status.startswith(expect_status)
        RESULTS.append((name, ok, f"{time.time()-t0:.1f}s", events))
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {name}  ({time.time()-t0:.1f}s)")
        if VERBOSE or not ok:
            for k, s in events:
                print(f"      {k}: {s}")
    except TimeoutError as e:
        RESULTS.append((name, False, f"TIMEOUT", str(e)))
        print(f"[T/O] {name}  gate silent — {e}")
    except Exception as e:
        RESULTS.append((name, False, "ERR", f"{type(e).__name__}: {e}"))
        print(f"[ERR] {name}  {type(e).__name__}: {e}")
    finally:
        g.close()


# ---------------------------------------------------------------- cases
# Each wire is ONE turn (terminated by blank line inside send_wire).

case("introspection: vocabulary()",
     'vocabulary()\n',
     ["status"], expect_status="OK")

case("introspection: grammar()",
     'grammar()\n',
     ["status"], expect_status="OK")

case("single call -> result -> OK",
     'get-user-details(user_id: "x")\n',
     ["call", "status"], expect_status="OK")

case("single say -> user reply -> OK",
     'say(text: "hello there")\n',
     ["say", "status"], expect_status="OK")

case("arm chain: call | ok u |> say",
     'get-user-details(user_id: "x") | ok u |>\nsay(text: "hi {{ u.user_id }}")\n',
     ["call", "say", "status"], expect_status="OK")

case("multi-item: say then call (HANG CASE)",
     'say(text: "one")\nget-user-details(user_id: "x")\n',
     ["say", "call", "status"])

case("multi-item: call then say (HANG CASE)",
     'get-user-details(user_id: "x")\nsay(text: "done")\n',
     ["call", "say", "status"])

case("two calls sequential",
     'get-user-details(user_id: "x")\nget-flight-status(flight_number: "AA1", date: "2024-01-01")\n',
     ["call", "call", "status"])

case("reject: prose is not wire",
     'hello this is prose not wire\n',
     ["status"], expect_status="REJECT")

case("reject: unknown verb",
     'frobnicate(x: 1)\n',
     ["status"], expect_status="REJECT")

case("empty say text still emits say event",
     'say(text: "")\n',
     ["say", "status"])

case("say with arm binding reply",
     'say(text: "what is your id?") | ok reply |>\nsay(text: "you said {{ reply }}")\n',
     ["say", "say", "status"])

case("bound field read in arg",
     'get-user-details(user_id: "x") | ok u |>\nget-reservation-details(reservation_id: u.user_id)\n',
     ["call", "call", "status"])


# ---------------------------------------------------------------- report
print(f"\n=== gate_probe vs {BINARY.name} (timeout={TIMEOUT}s) ===")
npass = sum(1 for _, ok, *_ in RESULTS if ok)
for name, ok, dt, ev in RESULTS:
    print(f"  {'PASS' if ok else 'FAIL/T-O':8} {name}  [{dt}]")
print(f"\n{npass}/{len(RESULTS)} passed")
sys.exit(0 if npass == len(RESULTS) else 1)
