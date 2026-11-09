"""TauGateSession — the airline/mock-real gate protocol (tau_wire.kz).

Unlike GateSession (wire-turn in → one status line out), this gate is a
full conversational runtime:

  IN   wire turn:   `verb(...)\n...\n\n`          (blank-line terminated)
       user reply:  `{"kind":"user","text":...}`  (say-reply / pending)
       tool result: `{"kind":"result","id":"kN","content":...,"error":bool}`
  OUT  `{"kind":"call","id":"kN","name":...,"arguments":{...}}`  tool request
       `{"kind":"say","text":...}`                             user-facing text
       `OK|HALT|REJECT|ERROR|STEPS|DEFINED ...`                 turn verdict

A turn can span MANY tau2 exchanges: say() blocks for the user reply,
callIO blocks for the tool result, and the program resumes after each.
The session tracks which outbound is outstanding so results route right.
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
        """What the gate is currently blocked on: 'call' | 'say' | None.
        Wire turns may ONLY be sent when this is None — sending source
        while sayIO/callIO reads inbound lines panics the gate
        ('inbound line is not JSON')."""
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

    def send_wire(self, source: str):
        """One wire turn -> first event: ('call',dict)|('say',dict)|
        ('status',status,detail)|('eof',)."""
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

    def feed_user(self, text: str):
        """Answer an outstanding say() (or pending user line) -> next event."""
        self._write(json.dumps({"kind": "user", "text": text}) + "\n")
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
                return ("status", "STEPS", "\n".join(lines))
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
                continue
            _, _, detail = line.partition(" ")
            self._await = None
            self._call_id = None
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
        ev = self.send_wire(f"{name}()")
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
