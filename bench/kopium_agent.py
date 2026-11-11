#!/usr/bin/env python3
"""
KopiumAgent — the tau2 marshal, nothing more.

The agent is bench/tau-agent.k (Koru): it owns the model call, the
transcript, the prompt, the gate, retries, and usage accounting. This file
is the in-process shim tau2 requires; it copies lines.

  in : {"kind":"init","policy":...} once, then
       {"kind":"user","text":...} for a UserMessage,
       {"kind":"result","id":...,"content":...} per ToolMessage.
  out: exactly one line per generate_next_message —
       {"kind":"say","text":...,"usage":{...},"cost":X|null} or
       {"kind":"call","id":...,"name":...,"arguments":{...}, ...}

A dead process, EOF, or a malformed line raises. There is no fallback reply:
if the wire is broken the run is broken.
"""

from __future__ import annotations

import json
import os
import select
import subprocess
import time
from contextlib import suppress
from pathlib import Path
from typing import Optional

from tau2.agent.base_agent import HalfDuplexAgent
from tau2.data_model.message import (
    AssistantMessage,
    Message,
    UserMessage,
    ToolCall,
    ToolMessage,
    MultiToolMessage,
)
from tau2.environment.toolkit import Tool

HERE = Path(__file__).parent

# A silent wire is a wedged wire: a dead agent whose stdout stays open (a
# grandchild inheriting the fd) blocks a bare readline() forever — measured
# 2026-09-28 when one such hang wedged a whole sweep in as_completed. A
# streamed model call may legitimately take minutes between turns, so the
# bound is generous; beyond it the run fails loudly instead of hanging.
READ_TIMEOUT_S = 900.0


class KopiumAgentState:
    """tau2 requires a state object; the conversation lives in Koru."""

    def __init__(self, messages: list[Message]):
        self.messages = messages


class KopiumAgent(HalfDuplexAgent[KopiumAgentState]):
    """Half-duplex marshal to the Koru agent process."""

    def __init__(
        self,
        tools: list[Tool],
        domain_policy: str,
        domain: str = "airline",
        gate_binary: Optional[Path] = None,
        llm: str = "unset/no-default-model",
        llm_args: Optional[dict] = None,
    ):
        super().__init__(tools=tools, domain_policy=domain_policy)
        self.domain = domain
        self.binary = Path(gate_binary) if gate_binary else HERE / "tau-agent-binary"
        # Reaches the binary as KOPIUM_MODEL in the spawned env — the agent
        # model is the litellm slug minus its "openrouter/" provider prefix.
        self.llm = llm
        self.call_count = 0
        self._proc: Optional[subprocess.Popen] = None
        self._buf = b""

    # ------------------------------------------------------------ the pipe
    def _ensure_proc(self) -> subprocess.Popen:
        if self._proc is not None and self._proc.poll() is None:
            return self._proc
        if self._proc is not None:
            raise RuntimeError(
                f"kopium agent exited (rc={self._proc.returncode}) before init"
            )
        if not self.binary.exists():
            raise FileNotFoundError(
                f"kopium agent binary missing: {self.binary} "
                f"(build with `koruc tau-agent.k` in {HERE})"
            )
        # bufsize=0: raw unbuffered stdout so _recv owns the bytes itself —
        # a select() on the fd then answers "will this read ever finish".
        self._proc = subprocess.Popen(
            [str(self.binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            cwd=HERE,
            bufsize=0,
            env={**os.environ, "KOPIUM_MODEL": self.llm.removeprefix("openrouter/")},
        )
        self._send({"kind": "init", "policy": self.domain_policy})
        return self._proc

    def _send(self, obj: dict) -> None:
        assert self._proc is not None and self._proc.stdin is not None
        self._proc.stdin.write(json.dumps(obj).encode() + b"\n")
        self._proc.stdin.flush()

    def _readline(self) -> bytes:
        assert self._proc is not None and self._proc.stdout is not None
        fd = self._proc.stdout.fileno()
        deadline = time.monotonic() + READ_TIMEOUT_S
        while True:
            nl = self._buf.find(b"\n")
            if nl >= 0:
                line, self._buf = self._buf[:nl], self._buf[nl + 1:]
                return line
            if self._proc.poll() is not None:
                r, _, _ = select.select([fd], [], [], 0)
                if not r:
                    return b""
            else:
                r, _, _ = select.select(
                    [fd], [], [], max(0.0, deadline - time.monotonic()))
                if not r:
                    raise RuntimeError(
                        f"kopium agent silent for {READ_TIMEOUT_S:.0f}s — "
                        "the wire is wedged, not slow"
                    )
            chunk = os.read(fd, 65536)
            if not chunk:
                line, self._buf = self._buf, b""
                return line
            self._buf += chunk

    def _recv(self) -> dict:
        assert self._proc is not None and self._proc.stdout is not None
        line = self._readline().decode("utf-8", errors="replace")
        rc = self._proc.poll()
        if not line:
            raise RuntimeError(
                f"kopium agent produced no output (process rc={rc}); "
                "stderr above is the wire's own account"
            )
        try:
            obj = json.loads(line)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"kopium agent emitted a non-JSON line: {line!r}") from e
        if not isinstance(obj, dict) or obj.get("kind") not in ("say", "call"):
            raise RuntimeError(f"kopium agent emitted a malformed line: {line!r}")
        return obj

    # ------------------------------------------------------------ the turn
    def get_init_state(
        self, message_history: Optional[list[Message]] = None
    ) -> KopiumAgentState:
        return KopiumAgentState(messages=list(message_history) if message_history else [])

    def generate_next_message(
        self, message: UserMessage, state: KopiumAgentState
    ) -> tuple[AssistantMessage, KopiumAgentState]:
        self.call_count += 1
        proc = self._ensure_proc()
        assert proc.stdin is not None

        if isinstance(message, MultiToolMessage):
            for tm in message.tool_messages:
                self._send({"kind": "result", "id": tm.id or "",
                            "content": tm.content or "",
                            "error": bool(tm.error)})
        elif isinstance(message, ToolMessage):
            self._send({"kind": "result", "id": message.id or "",
                        "content": message.content or "",
                        "error": bool(message.error)})
        elif isinstance(message, UserMessage):
            self._send({"kind": "user", "text": message.content or ""})
        else:
            raise TypeError(f"kopium marshal cannot carry {type(message).__name__}")

        obj = self._recv()
        usage = obj.get("usage")
        cost = obj.get("cost")
        if obj["kind"] == "say":
            out = AssistantMessage.text(obj["text"], usage=usage, cost=cost)
        else:
            out = AssistantMessage(
                role="assistant",
                content=None,
                tool_calls=[ToolCall(
                    id=obj["id"], name=obj["name"],
                    arguments=obj.get("arguments") or {},
                )],
                usage=usage,
                cost=cost,
            )
        state.messages.append(out)
        return out, state

    def stop(
        self,
        message: Optional[Message] = None,
        state: Optional[KopiumAgentState] = None,
    ) -> None:
        """EOF on stdin is the conversation-over signal."""
        if self._proc is None:
            return
        if self._proc.stdin is not None and self._proc.poll() is None:
            with suppress(BrokenPipeError):
                self._proc.stdin.close()
        try:
            self._proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self._proc.kill()
            self._proc.wait()
        self._proc = None
