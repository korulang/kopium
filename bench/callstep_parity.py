#!/usr/bin/env python3
"""callstep_parity.py — the same scripted wire through BOTH agent paths.

Path A (gate): TauGateSession(airline-gate-binary) — the session
AirlineLldaAgent drives. Records arrive as the CALLSTEPS block after each
verdict and drain via drain_callsteps() (what becomes runlog `call_step`
events, origin="model" for agent wires).

Path B (agent): tau-agent-binary — the all-Koru agent (ask -> drive ->
act -> drain-calls -> write-callsteps). Zero model spend: KOPIUM_API_URL
points `send` at a local SSE stub serving canned replies, so the whole
loop runs for real. Records land as callsteps_NNN.jsonl under
KOPIUM_RECEIPT_DIR with "origin" injected per drain.

Comparison: (turn, step, verb, item_outcome) sequences over the shared
wire turns must be identical. Turn numbering aligns because each agent
reply is exactly one std/bridge:run on both paths (the gate's harness
vocabulary() flush turn and the agent's sentinel/EOF-bait turns are
excluded by turn bound and origin).

Usage: python3 callstep_parity.py [gate_binary] [agent_binary]
"""

import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from tau_gate_session import TauGateSession  # noqa: E402

GATE = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "airline-gate-binary"
AGENT = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "tau-agent-binary"

# The shared script: each entry is ONE model reply = ONE gate turn.
# Covers say-only, armed chains (one-line and cross-line), a prose
# refusal, an unbound-name arg-eval failure, and a call needing a result.
WIRES = [
    'say(text: "hello there")\n',
    'get-user-details(user_id: "x") | ok u |>\nsay(text: "hi {{ u.user_id }}")\n',
    'this is not wire\n'
    'get-user-details(user_id: "x") | ok u |> say(text: "hi {{ u.user_id }}")\n'
    'say(text: "{{ missing.field }}")\n',
    'say(text: "q?") | ok r |>\nsay(text: "you said {{ r }}")\n',
    'get-flight-status(flight_number: "AA1", date: "2024-01-01") | ok f |>\n'
    'say(text: "flight {{ f.flight_number }}")\n',
]
N_TURNS = len(WIRES)
SENTINEL = 'say(text: "__parity_done__")\n'
EOF_BAIT = 'get-user-details(user_id: "x")\n'  # blocks on result; stdin EOF ends the session
CALL_RESULT = '{"user_id":"x","membership":"gold","flight_number":"AA1"}'
USER_REPLY = "parity user reply"


def sse_response(wire: str) -> bytes:
    """One chat-completion SSE stream: content deltas + usage + [DONE]."""
    parts = []
    chunk = {"id": "parity", "choices": [{"index": 0, "delta": {"content": wire}}]}
    parts.append("data: " + json.dumps(chunk) + "\n\n")
    usage = {"id": "parity", "choices": [],
             "usage": {"prompt_tokens": 10, "completion_tokens": 5,
                       "cached_tokens": 0, "cost": 0.0}}
    parts.append("data: " + json.dumps(usage) + "\n\n")
    parts.append("data: [DONE]\n\n")
    return "".join(parts).encode()


class Stub(BaseHTTPRequestHandler):
    script = [sse_response(w) for w in WIRES] + [
        sse_response(SENTINEL)]
    hits = 0

    def do_POST(self):  # noqa: N802
        body = sse_response(EOF_BAIT) if Stub.hits >= len(Stub.script) \
            else Stub.script[Stub.hits]
        Stub.hits += 1
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


def path_gate() -> list[dict]:
    """Wires through TauGateSession — the airline agent's gate path."""
    g = TauGateSession(GATE)
    try:
        for wire in WIRES:
            ev = g.send_wire(wire, origin="model")
            steps = 0
            while steps < 20:
                steps += 1
                k = ev[0]
                if k == "call":
                    ev = g.feed_result(ev[1].get("id"), CALL_RESULT, error=False)
                elif k == "say":
                    ev = g.next_event()
                elif k == "status":
                    break
                else:
                    raise RuntimeError(f"gate event {k}")
        # Flush: the last turn's CALLSTEPS parses on the next read; the
        # throwaway vocabulary() turn's own records stay in the pipe.
        ev = g.send_wire("vocabulary()\n", origin="harness")
        while ev[0] != "status":
            ev = g.next_event() if ev[0] == "say" else g.feed_result(
                ev[1].get("id"), "{}", error=True)
        recs = [r for r in g.drain_callsteps() if r.get("origin") == "model"]
        return [r for r in recs if (r.get("turn") or 0) <= N_TURNS]
    finally:
        g.close()


def path_agent(receipt_dir: Path) -> list[dict]:
    """Wires through tau-agent-binary against the local SSE stub."""
    env = dict(os.environ)
    env.update({
        "KOPIUM_MODEL": "parity-script",
        "KOPIUM_RECEIPT_DIR": str(receipt_dir),
        "KOPIUM_API_URL": f"http://127.0.0.1:{Stub.port}/chat/completions",
        "OPENROUTER_API_KEY": "parity-no-spend",
    })
    proc = subprocess.Popen(
        [str(AGENT)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, text=True, bufsize=1, env=env)
    lines: queue.Queue = queue.Queue()
    threading.Thread(
        target=lambda: [lines.put(l) for l in proc.stdout] or lines.put(None),
        daemon=True).start()

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    send({"kind": "init", "policy": "parity domain policy"})
    send({"kind": "user", "text": "parity task"})
    sentinel_seen = False
    while proc.poll() is None:
        try:
            line = lines.get(timeout=30)
        except queue.Empty:
            break
        if line is None:
            break
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = obj.get("kind")
        if kind == "say":
            send({"kind": "user", "text": USER_REPLY})
            if "__parity_done__" in str(obj.get("text", "")) and not sentinel_seen:
                sentinel_seen = True
                proc.stdin.close()  # EOF after the owed reply: session ends
        elif kind == "call":
            try:
                send({"kind": "result", "id": obj.get("id", ""),
                      "content": CALL_RESULT, "error": False})
            except (BrokenPipeError, ValueError):
                pass
    proc.wait(timeout=10)
    recs = []
    for f in sorted(receipt_dir.glob("callsteps_*.jsonl")):
        for ln in f.read_text().splitlines():
            try:
                recs.append(json.loads(ln))
            except json.JSONDecodeError:
                pass
    return [r for r in recs
            if r.get("origin") == "model" and (r.get("turn") or 0) <= N_TURNS]


def tuples(recs):
    return [(r.get("turn"), r.get("step"), r.get("verb"),
             r.get("item_outcome")) for r in recs]


def main():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), Stub)
    Stub.port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    with tempfile.TemporaryDirectory() as td:
        t0 = time.time()
        a_recs = path_gate()
        b_recs = path_agent(Path(td))
        srv.shutdown()

    a_t, b_t = tuples(a_recs), tuples(b_recs)
    print(f"=== gate path ({GATE.name}): {len(a_recs)} records ===")
    for r in a_recs:
        print(f"  t={r.get('turn')} s={r.get('step')}/{r.get('of')} "
              f"out={r.get('item_outcome')} verb={r.get('verb')!r} "
              f"seq={r.get('seq')} origin={r.get('origin')}")
    print(f"=== agent path ({AGENT.name}): {len(b_recs)} records ===")
    for r in b_recs:
        print(f"  t={r.get('turn')} s={r.get('step')}/{r.get('of')} "
              f"out={r.get('item_outcome')} verb={r.get('verb')!r} "
              f"seq={r.get('seq')} origin={r.get('origin')}")
    print(f"=== compare ({time.time()-t0:.1f}s) ===")
    print(f"gate : {a_t}")
    print(f"agent: {b_t}")
    if a_t == b_t and a_t:
        print(f"PARITY: IDENTICAL ({len(a_t)} records)")
        sys.exit(0)
    print("PARITY: MISMATCH")
    sys.exit(1)


if __name__ == "__main__":
    main()
