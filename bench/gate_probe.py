#!/usr/bin/env python3
"""gate_probe.py — deterministic wire-level tests for the KOPIUM gate.

No LLM, no tau2, no orchestrator: scripted wire programs fed straight to
the gate binary via TauGateSession. This is the layer that should have
been tested algorithmically all along — every protocol bug we chased
through full simulations (status misclassification, STEPS awaiting,
empty says, malformed call JSON, multi-item hangs, say-protocol desync)
is reproducible here in seconds.

Protocol under test (tau_wire.kz + airline-gate.k, measured 2026-11-09):

  - say is EMIT-ONLY. sayIO writes the line and returns the text; the
    gate keeps running. The harness never answers a say — there is no
    feed_user on this gate, and a {"kind":"user"} line written between
    turns becomes the next turn's wire residue (pinned below).
  - call is the ONLY blocking state: callIO emits {"kind":"call"} then
    reads inbound lines until the matching {"kind":"result"} arrives.
  - A turn's item count = its line count. Arm chains joined on one line
    are ONE item (OK verdict); the same chain across two lines is TWO
    items (STEPS report). An unarmed outcome on a single-item turn is
    HALT; inside a multi-item turn it is a per-step
    `unhandled-branch:` line that does NOT stop sibling items.
  - say's `| ok x |>` arm binds the EMITTED TEXT, not a user reply.

Each case: send wire -> pump events (say->read-only drain,
call->feed_result) -> assert the exact event-kind sequence + status.
A case that hangs hits TAU_GATE_TIMEOUT and reports TIMEOUT.

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


def pump(g, wire, call_result='{"ok":true}', max_events=12):
    """One wire turn -> events until the status verdict.

    say drains read-only via next_event — the gate already moved on.
    call answers via feed_result — the only legal inbound write.
    NOTHING ever writes {"kind":"user"} to this gate."""
    events = []
    ev = g.send_wire(wire)
    while len(events) < max_events:
        kind = ev[0]
        if kind == "call":
            obj = ev[1]
            events.append(("call", f"{obj.get('name')} {obj.get('arguments')}"))
            ev = g.feed_result(obj.get("id"), call_result, error=False)
        elif kind == "say":
            text = str(ev[1].get("text", ""))
            events.append(("say", text[:60]))
            ev = g.next_event()
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


def run_turns(g, turns):
    """turns: list of (wire, call_result). Flat event list across turns —
    residue only manifests turn-over-turn in ONE session, so multi-turn
    pins need this."""
    events = []
    for wire, result in turns:
        events.extend(pump(g, wire, call_result=result))
    return events


def case(name, wire, expect_kinds, expect_status=None,
         call_result='{"ok":true}', expect_say_last=None, turns=None):
    """Run wire turn(s); assert exact event-kind sequence, optional
    status prefix on the last status, optional substring in the LAST
    say's text."""
    global CURRENT_WIRE
    CURRENT_WIRE = wire
    g = TauGateSession(BINARY)
    t0 = time.time()
    try:
        if turns is None:
            turns = [(wire, call_result)]
        events = run_turns(g, turns)
        kinds = [e[0] for e in events]
        status = next((e[1] for e in reversed(events) if e[0] == "status"), None)
        ok = kinds == expect_kinds
        if expect_status:
            ok = ok and status is not None and status.startswith(expect_status)
        if expect_say_last is not None:
            says = [s for k, s in events if k == "say"]
            ok = ok and says and expect_say_last in says[-1]
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

case("say is emit-only: say -> status, no reply owed",
     'say(text: "hello there")\n',
     ["say", "status"], expect_status="OK")

case("unarmed call -> HALT unhandled-branch (arms are mandatory)",
     'get-user-details(user_id: "x")\n',
     ["call", "status"], expect_status="HALT")

case("armed chain, one line -> single item OK",
     'get-user-details(user_id: "x") | ok u |>'
     'say(text: "hi {{ u.user_id }}")\n',
     ["call", "say", "status"], expect_status="OK",
     call_result='{"user_id":"x"}')

case("armed chain, two lines -> two items STEPS",
     'get-user-details(user_id: "x") | ok u |>\n'
     'say(text: "hi {{ u.user_id }}")\n',
     ["call", "say", "status"], expect_status="STEPS",
     call_result='{"user_id":"x"}')

case("multi-item: say then bare call (unhandled step, siblings continue)",
     'say(text: "one")\nget-user-details(user_id: "x")\n',
     ["say", "call", "status"], expect_status="STEPS")

case("multi-item: say then armed chain",
     'say(text: "one")\n'
     'get-user-details(user_id: "x") | ok u |>'
     'say(text: "two {{ u.user_id }}")\n',
     ["say", "call", "say", "status"], expect_status="STEPS",
     call_result='{"user_id":"x"}')

case("multi-item: call-arm then say",
     'get-user-details(user_id: "x") | ok u |>\n'
     'say(text: "done {{ u.user_id }}")\n',
     ["call", "say", "status"], expect_status="STEPS",
     call_result='{"user_id":"x"}')

case("two bare calls: unhandled steps do not halt siblings",
     'get-user-details(user_id: "x")\n'
     'get-flight-status(flight_number: "AA1", date: "2024-01-01")\n',
     ["call", "call", "status"], expect_status="STEPS")

case("two armed chains: call,say per item",
     'get-user-details(user_id: "x") | ok u |>'
     'say(text: "a {{ u.user_id }}")\n'
     'get-flight-status(flight_number: "AA1", date: "2024-01-01") | ok f |>'
     'say(text: "b {{ f.flight_number }}")\n',
     ["call", "say", "call", "say", "status"], expect_status="STEPS",
     call_result='{"user_id":"x","flight_number":"AA1","ok":true}')

case("reject: prose is not wire",
     'hello this is prose not wire\n',
     ["status"], expect_status="REJECT")

case("reject: unknown verb",
     'frobnicate(x: 1)\n',
     ["status"], expect_status="REJECT")

case("empty say text still emits say event",
     'say(text: "")\n',
     ["say", "status"], expect_status="OK")

case("say arm binds the EMITTED TEXT, not a reply",
     'say(text: "what is your id?") | ok reply |>\n'
     'say(text: "you said {{ reply }}")\n',
     ["say", "say", "status"], expect_status="STEPS",
     expect_say_last="you said what is your id?")

case("bound field read in arg",
     'get-user-details(user_id: "x") | ok u |>\n'
     'get-reservation-details(reservation_id: u.user_id)\n',
     ["call", "call", "status"], expect_status="STEPS",
     call_result='{"user_id":"x","reservation_id":"x"}')

case("two turns one session: say, say — no residue",
     'say(text: "first")\n',
     ["say", "status", "say", "status"], expect_status="OK",
     turns=[('say(text: "first")\n', '{"ok":true}'),
            ('say(text: "second")\n', '{"ok":true}')])


# ------------------------------------------------- session-level pins
def residue_trap():
    """A {"kind":"user"} line written while the gate sits at intake
    becomes the FIRST LINE of the next wire turn — intake has no kind
    dispatch. This is the measured residue mechanism from run
    airline-14-...-181050 and the reason feed_user does not exist.
    Pin: inject the line raw, then a clean say turn — the report must
    show the JSON glued in as a residue item."""
    g = TauGateSession(BINARY)
    t0 = time.time()
    try:
        events = pump(g, 'say(text: "first")\n')
        # the OLD bug: answering a say with a user JSON line
        g._write('{"kind":"user","text":"poison"}\n')
        events += pump(g, 'say(text: "second")\n')
        kinds = [e[0] for e in events]
        status = next((e[1] for e in reversed(events) if e[0] == "status"), "")
        ok = (kinds == ["say", "status", "say", "status"]
              and "residue" in status.lower())
        RESULTS.append(("user line at intake -> wire residue (trap pin)",
                        ok, f"{time.time()-t0:.1f}s", events))
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] user line at intake -> wire residue (trap pin)  ({time.time()-t0:.1f}s)")
        if VERBOSE or not ok:
            for k, s in events:
                print(f"      {k}: {s}")
    except Exception as e:
        RESULTS.append(("user line at intake -> wire residue (trap pin)",
                        False, "ERR", f"{type(e).__name__}: {e}"))
        print(f"[ERR] residue trap  {type(e).__name__}: {e}")
    finally:
        g.close()


residue_trap()


# ---------------------------------------------------------------- report
print(f"\n=== gate_probe vs {BINARY.name} (timeout={TIMEOUT}s) ===")
npass = sum(1 for _, ok, *_ in RESULTS if ok)
for name, ok, dt, ev in RESULTS:
    print(f"  {'PASS' if ok else 'FAIL/T-O':8} {name}  [{dt}]")
print(f"\n{npass}/{len(RESULTS)} passed")
sys.exit(0 if npass == len(RESULTS) else 1)
