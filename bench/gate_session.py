"""One long-lived gate process — one Bridge; invocations, defines, vocabulary."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path


class GateSession:
    def __init__(self, binary: Path):
        binary = Path(binary)
        if not binary.exists():
            raise FileNotFoundError(f"gate binary missing: {binary}")
        self.binary = binary
        self.proc = subprocess.Popen(
            [str(binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )

    @property
    def alive(self) -> bool:
        return self.proc.poll() is None

    def send(self, source: str) -> tuple[str, str]:
        if not self.alive:
            return "ERROR", "gate process died"
        assert self.proc.stdin is not None and self.proc.stdout is not None
        # A wire turn is the whole reply, one item per line, terminated by
        # a blank line — the gate reads until that terminator and `run`
        # segments the turn. Without it a multi-line reply desyncs the
        # protocol: each line answered by a later send().
        payload = source.replace("\r\n", "\n").rstrip("\n") + "\n\n"
        if payload == "\n\n":
            # An empty first line is `ready` immediately — sending the
            # terminator too would leave a stray blank line in the pipe
            # that the NEXT send reads as its own turn (measured desync).
            payload = "\n"
        try:
            self.proc.stdin.write(payload.encode())
            self.proc.stdin.flush()
            raw = self.proc.stdout.readline()
        except BrokenPipeError:
            return "ERROR", "gate process died"
        if not raw:
            return "ERROR", "gate produced no output"
        stdout = raw.decode(errors="replace").strip()
        if stdout == "STEPS-BEGIN":
            lines: list[str] = []
            while True:
                raw = self.proc.stdout.readline()
                if not raw:
                    return "ERROR", "gate produced no STEPS-END"
                line = raw.decode(errors="replace").rstrip("\n").rstrip("\r")
                if line == "STEPS-END":
                    return "STEPS", "\n".join(lines)
                lines.append(line)
        status, _, detail = stdout.partition(" ")
        return status, detail.strip()

    @staticmethod
    def parse_ok(detail: str) -> tuple[str, str, str]:
        """`OK <verb> bound=<name> <result-json>` → (verb, bound name, json).
        `bound` is "" only if the gate's auto-bind ran out of memory."""
        verb, _, rest = detail.partition(" ")
        bound = ""
        if rest.startswith("bound="):
            bound, _, rest = rest[len("bound="):].partition(" ")
        return verb, bound, rest

    def bind(self, name: str, value: str) -> str:
        """Inject a datum into the session env — the result-injection verb.
        The value is a rendered datum (JSON object → named fields), and the
        name is referenceable on every later turn (`t1.user_id`). Returns
        the REQUESTED name — the OK line's `bound=r{N}` is the auto-bind of
        the bind call's own ack value, not where the datum lives; handing
        it back made the context render `[r2]` for a value bound as `t1`."""
        status, detail = self.send(
            f'bind(name: "{name}", value: {json.dumps(value)})'
        )
        if status != "OK":
            raise RuntimeError(f"bind({name}) -> {status} {detail}")
        return name

    def _host_verb(self, name: str) -> str:
        """A host verb on the wire — `vocabulary()`/`grammar()` dispatch like
        any call; the render arrives inside the OK line's result JSON."""
        status, detail = self.send(f"{name}()")
        if status != "OK":
            raise RuntimeError(f"{name}() -> {status} {detail}")
        _, _, payload = self.parse_ok(detail)
        try:
            return json.loads(payload)["value"]
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            raise RuntimeError(f"{name}() returned unparseable result: {detail!r}") from e

    def vocabulary(self) -> str:
        """`vocabulary()` on this Bridge — register, host verbs, inventions."""
        return self._host_verb("vocabulary")

    def grammar(self) -> str:
        """`grammar()` — wire rules, compiled verbs, inventions (440_017)."""
        return self._host_verb("grammar")

    def close(self) -> None:
        if self.proc.stdin:
            try:
                self.proc.stdin.close()
            except BrokenPipeError:
                pass
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=2)
