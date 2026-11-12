"""TauGateSession — the airline/mock-real gate protocol (tau_wire.kz).

Unlike GateSession (wire-turn in → one status line out), this gate is a
full conversational runtime:

  IN   wire turn:   `verb(...)\n...\n\n`          (blank-line terminated)
       tool result: `{"kind":"result","id":"kN","content":...,"error":bool}`
  OUT  `{"kind":"call","id":"kN","name":...,"arguments":{...}}`  tool request
       `{"kind":"say","text":...}`                             user-facing text
       `OK|HALT|REJECT|ERROR|STEPS|DEFINED ...`                 turn verdict

Protocol truth (tau_wire.kz sayIO/callIO + airline-gate.k serve loop):

  - `call` is the ONLY blocking state. callIO emits the call line then
    reads inbound lines until the matching result arrives.
  - `say` is emit-only: sayIO writes the line and returns the text
    immediately. The gate has already moved on — there is nothing to
    answer. Say-debt (outstanding_user) exists for tau-agent.k's
    pull()/take-pending transcript drain; airline-gate.k never calls
    them, so the debt is inert here.
  - `{"kind":"user"}` lines are NEVER written to this gate. intake has
    no kind dispatch — a user line landing between turns becomes the
    first line of the next wire turn (measured: '{"kind":"user",...}'
    glued into wire text as a residue item). User replies live at the
    transcript level: tau2's user sim produces them, the agent observes
    them, and the next generation sees them. They never enter the gate.

The session tracks _await: "call" = blocked in callIO (feed_result is
the only legal write), "say" = gate running (read-only — pump events,
write nothing), None = status consumed, gate at intake (send_wire legal).
"""

from __future__ import annotations

import json
import os
import queue
import subprocess
import threading
from pathlib import Path

_EOF = object()  # sentinel: reader thread ended (gate stdout closed)


class TauGateSession:
    def __init__(self, binary: Path):
        binary = Path(binary)
        if not binary.exists():
            raise FileNotFoundError(f"gate binary missing: {binary}")
        self.binary = binary
        errlog = os.environ.get("TAU_GATE_STDERR")
        self.proc = subprocess.Popen(
            [str(binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=open(errlog, "w") if errlog else subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        # Reader thread: readline() blocks correctly on the buffered
        # stream; the queue gives _readline honest timeouts.
        self._lines: queue.Queue = queue.Queue()
        self._reader = threading.Thread(
            target=self._pump_lines, daemon=True
        )
        self._reader.start()
        self._await: str | None = None  # "call" | "say" | None
        self._call_id: str | None = None
        self._callsteps: list[dict] = []  # drained per-dispatch records
        # Every stdout line a turn emitted that is neither an event nor a
        # known status verdict (a trace continuation, a guide line, a HALT's
        # appended detail). Kept so a harness can assert on the gate's full
        # model-visible output, not only the first status line.
        self._unframed: list[str] = []
        self._wire_origin = "model"       # origin of the in-flight wire
        self._pending_origin = "model"    # origin snapshotted at the verdict —
        # CALLSTEPS parses lazily on the NEXT turn's reads, by which time
        # _wire_origin already names the new wire; the verdict-time
        # snapshot is what the drained records actually belong to.

    def _pump_lines(self) -> None:
        assert self.proc.stdout is not None
        for line in self.proc.stdout:
            self._lines.put(line)
        self._lines.put(_EOF)

    @property
    def alive(self) -> bool:
        return self.proc.poll() is None

    @property
    def awaiting(self) -> str | None:
        """What the gate is doing: 'call' = blocked in callIO (only
        feed_result is a legal write), 'say' = mid-program (read-only —
        the gate already moved past the say), None = at intake
        (send_wire is legal). Wire turns may ONLY be sent when this is
        None — sending source while callIO reads inbound lines panics
        the gate ('inbound line is not JSON'), and any {"kind":"user"}
        line written while the gate is NOT inside callIO becomes the
        next turn's wire residue."""
        return self._await

    def _write(self, s: str) -> None:
        assert self.proc.stdin is not None
        if os.environ.get("TAU_GATE_LOG"):
            with open(os.environ["TAU_GATE_LOG"], "a") as f:
                f.write(">>> " + s.replace("\n", "\\n")[:400] + "\n")
        self.proc.stdin.write(s)
        self.proc.stdin.flush()

    def _readline(self, timeout: float | None = None) -> str | None:
        """One stdout line via the reader thread's queue.

        The old select-on-fd + buffered-readline combo had a fatal flaw:
        TextIOWrapper buffers ahead — after a burst (STEPS-BEGIN + report
        lines + STEPS-END arrive in one write), the kernel fd is empty
        while Python's buffer holds the rest, so select reported "silent"
        and raised TimeoutError on data that was already read. Every
        "gate hang" in this project's history was this bug, not the gate.
        A dedicated reader thread + queue makes timeouts honest."""
        if timeout is None:
            env_t = os.environ.get("TAU_GATE_TIMEOUT")
            timeout = float(env_t) if env_t else None
        try:
            line = self._lines.get(timeout=timeout)
        except queue.Empty:
            raise TimeoutError(
                f"gate silent {timeout}s — awaiting={self._await} "
                f"call_id={self._call_id} alive={self.alive}"
            )
        if line is _EOF:
            return None
        out = line.rstrip("\n").rstrip("\r")
        if os.environ.get("TAU_GATE_LOG"):
            with open(os.environ["TAU_GATE_LOG"], "a") as f:
                f.write("<<< " + out[:400] + "\n")
        return out

    def send_wire(self, source: str, origin: str = "model"):
        """One wire turn -> first event: ('call',dict)|('say',dict)|
        ('status',status,detail)|('eof',). `origin` marks who issued the
        wire — 'model' for agent-emitted programs, 'harness' for the
        session's own introspection calls (grammar()/vocabulary()); it is
        stamped onto the turn's call_step records when CALLSTEPS parses."""
        self._wire_origin = origin
        payload = source.replace("\r\n", "\n").rstrip("\n") + "\n\n"
        self._write(payload)
        return self._next_event()

    def feed_result(self, call_id: str, content: str, error: bool = False):
        """Answer an outstanding {"kind":"call"} -> next event."""
        self._write(json.dumps({
            "kind": "result", "id": call_id,
            "content": content, "error": error,
        }) + "\n")
        return self._next_event()

    def drain_unframed(self) -> list[str]:
        """Return and clear the non-event stdout lines seen since the last
        drain — OK/HALT trace continuations, guide lines, appended detail."""
        out = self._unframed
        self._unframed = []
        return out

    def drain_callsteps(self) -> list[dict]:
        """Return and clear the call_step records collected since the last
        drain — the agent logs each as a runlog `call_step` event."""
        out = self._callsteps
        self._callsteps = []
        return out

    def next_event(self):
        """Read the next gate event WITHOUT writing anything.

        Legal only while awaiting == 'say' (or 'call' is impossible —
        a blocked callIO emits nothing until its result arrives). Say is
        emit-only: after a say event the gate is already running toward
        its next emission, so the harness drains events read-only. There
        is deliberately no feed_user: this gate has no user-input verb —
        a {"kind":"user"} line at intake becomes wire residue."""
        if self._await != "say":
            raise RuntimeError(
                f"next_event while awaiting={self._await} — "
                "only a running gate (post-say) emits without input"
            )
        return self._next_event()

    def _next_event(self):
        """Read stdout until an emittable event or turn verdict.
        STEPS framing is consumed to its END marker."""
        while True:
            line = self._readline()
            if line is None:
                return ("eof",)
            if line == "STEPS-BEGIN":
                lines = []
                while True:
                    l2 = self._readline()
                    if l2 is None:
                        return ("eof",)
                    if l2 == "STEPS-END":
                        break
                    lines.append(l2)
                # STEPS is a terminal turn verdict (partial-program report)
                # — same as OK/HALT: every call resolved, gate is at intake.
                # Leaving _await set here desyncs the next send_wire into a
                # gate that already moved on.
                self._await = None
                self._call_id = None
                self._pending_origin = self._wire_origin
                return ("status", "STEPS", "\n".join(lines))
            if line == "CALLSTEPS-BEGIN":
                # Structured per-dispatch records, emitted AFTER the turn
                # verdict — collect them inline and keep reading; the gate
                # is already at intake. The agent drains the buffer into
                # the runlog; records carry their own turn/step/outcome so
                # attribution survives the one-turn delay.
                while True:
                    l2 = self._readline()
                    if l2 is None:
                        return ("eof",)
                    if l2 == "CALLSTEPS-END":
                        break
                    try:
                        rec = json.loads(l2)
                        rec["origin"] = self._pending_origin
                        self._callsteps.append(rec)
                    except json.JSONDecodeError:
                        continue
                continue
            if line.startswith("{"):
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    # The gate splices wire arg text into the call line
                    # verbatim — a model that writes unquoted JSON keys
                    # inside a composite arg produces a malformed call
                    # event. Skipping it deadlocks callIO (gate waits for
                    # a result we never send because we never saw the
                    # call). Salvage call events leniently; anything else
                    # unparseable is logged and skipped.
                    obj = self._salvage_call(line)
                    if obj is None:
                        if os.environ.get("TAU_GATE_LOG"):
                            with open(os.environ["TAU_GATE_LOG"], "a") as f:
                                f.write(f"!!! unparseable gate line: {line[:300]}\n")
                        continue
                kind = obj.get("kind")
                if kind == "call":
                    self._await = "call"
                    self._call_id = obj.get("id", "")
                    return ("call", obj)
                if kind == "say":
                    self._await = "say"
                    return ("say", obj)
                # other JSON kinds: ignore (usage/cost lines etc.)
                continue
            # Only KNOWN status prefixes end a turn. Anything else —
            # blank keepalives, echoes, partial lines — is skipped: a
            # misread "status" clears _await and the next send_wire hits
            # a blocked sayIO/callIO reader -> gate panic.
            status = line.split(" ", 1)[0]
            if status not in ("OK", "HALT", "REJECT", "ERROR", "DEFINED"):
                self._unframed.append(line)
                continue
            _, _, detail = line.partition(" ")
            self._await = None
            self._call_id = None
            self._pending_origin = self._wire_origin
            return ("status", status, detail.strip())

    @staticmethod
    def _salvage_call(line: str) -> dict | None:
        """Best-effort parse of a malformed {\"kind\":\"call\"...} line.
        Extracts id/name/arguments-substring; arguments get a second
        json.loads attempt, else {} — tau2's env will reject bad args
        honestly instead of the session deadlocking."""
        if '"kind":"call"' not in line and '"kind": "call"' not in line:
            return None
        import re
        mid = re.search(r'"id"\s*:\s*"([^"]*)"', line)
        mname = re.search(r'"name"\s*:\s*"([^"]*)"', line)
        margs = re.search(r'"arguments"\s*:\s*(.*)', line)
        args: dict = {}
        raw = None
        if margs:
            raw = margs.group(1).rsplit(',"usage"', 1)[0].rsplit(',"cost"', 1)[0]
            raw = raw.rstrip().rstrip(",}").rstrip()
            try:
                parsed = json.loads(raw if raw.startswith("{") else "{" + raw + "}")
                if isinstance(parsed, dict):
                    args = parsed
            except Exception:
                args = {}
        return {
            "kind": "call",
            "id": mid.group(1) if mid else "",
            "name": mname.group(1) if mname else "",
            "arguments": args,
            "_malformed_args": raw[:300] if raw else None,
        }

    def vocabulary(self) -> str:
        return self._host("vocabulary")

    def grammar(self) -> str:
        return self._host("grammar")

    def _host(self, name: str) -> str:
        ev = self.send_wire(f"{name}()", origin="harness")
        while ev[0] == "call":
            ev = self.feed_result(ev[1]["id"], "{}", error=True)
        if ev[0] != "status" or ev[1] != "OK":
            raise RuntimeError(f"{name}() -> {ev}")
        # detail = '<verb> bound=rN {"branch":..,"value":"<render>"}'
        rest = ev[2]
        _, _, payload = rest.partition(" bound=")
        payload = payload.split(" ", 1)[1] if " " in payload else payload
        try:
            return json.loads(payload)["value"]
        except Exception as e:
            raise RuntimeError(f"{name}() unparseable: {rest[:200]!r}") from e

    def close(self) -> None:
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
            self.proc.wait(timeout=2)
        except Exception:
            try:
                self.proc.kill()
                self.proc.wait(timeout=2)
            except Exception:
                pass
