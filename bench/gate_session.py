"""One long-lived gate process — one Bridge; invocations, defines, vocabulary."""

from __future__ import annotations

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

    def _framed(self, command: str, tag: str) -> str:
        if not self.alive:
            raise RuntimeError("gate process died")
        assert self.proc.stdin is not None and self.proc.stdout is not None
        try:
            self.proc.stdin.write((command + "\n").encode())
            self.proc.stdin.flush()
        except BrokenPipeError as e:
            raise RuntimeError("gate process died") from e
        begin, end = f"{tag}-BEGIN", f"{tag}-END"
        lines: list[str] = []
        began = False
        while True:
            raw = self.proc.stdout.readline()
            if not raw:
                raise RuntimeError(f"gate produced no {tag.lower()}")
            line = raw.decode(errors="replace").rstrip("\n").rstrip("\r")
            if not began:
                if line.startswith("ERROR"):
                    raise RuntimeError(line)
                if line != begin:
                    raise RuntimeError(f"expected {begin}, got {line!r}")
                began = True
                continue
            if line == end:
                return "\n".join(lines)
            lines.append(line)

    def vocabulary(self) -> str:
        """`std/bridge:vocabulary` on this Bridge — register plus inventions."""
        return self._framed(".vocabulary", "VOCAB")

    def grammar(self) -> str:
        """`std/bridge:grammar` — wire rules, compiled verbs, inventions (440_017)."""
        return self._framed(".grammar", "GRAMMAR")

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
