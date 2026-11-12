#!/usr/bin/env python3
"""live_guides_smoke.py — drive bench/tau-agent-binary against a LIVE model
and prove the R4 guide rails fire on a real run.

This is the live-model half of `guides-replay.py`: that harness replays the
corpus deterministically; this one lets a model choose the dispatches and
answers them with the real tau2 airline environment, then reports what the
gate recorded and what the model next saw.

Local-only by construction: no spend. Point KOPIUM_API_URL at an
OpenAI-compatible local endpoint (Ollama:

  KOPIUM_API_URL=http://localhost:11434/v1/chat/completions

) and it uses the agent's own chat-completions path. Refuses any non-local
endpoint so a smoke can never silently reach a paid provider.

  PYTHONPATH=bench <tau2-venv>/bin/python bench/live_guides_smoke.py \
      --model qwen2.5-coder:14b \
      --turn "Hi, I'm emma_kim_9957. Please look up my account details." \
      --turn "And my most recent reservation, with its flights?" \
      --turn "Thanks, that's all."

Writes receipts (call_*.json request bodies, callsteps_*.jsonl records,
resp_*.txt model replies) under --receipt-dir (default
bench/results/localsmoke/<stamp>/receipts) and prints the guide evidence:

  - guide fires per call_step (`fired_guides`)
  - guide text sightings in the model-visible channel (subsequent request
    bodies) and in the observed tool-result text fed back
  - once-per-session silence check (same key never fired twice)
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import select
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
AGENT_PIN = HERE / "tau-agent-binary"
READ_TIMEOUT_S = 900.0
LOCAL_HOSTS = ("localhost", "127.0.0.1", "[::1]")


def _local_only(url: str) -> bool:
    m = re.match(r"^https?://([^/:]+)", url)
    return bool(m) and m.group(1) in LOCAL_HOSTS


class Agent:
    """The tau-agent-binary protocol: init → user/result in, say/call out."""

    def __init__(self, binary: Path, env_vars: dict[str, str]):
        self.buf = b""
        self.proc = subprocess.Popen(
            [str(binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=None,  # the agent's log stays visible
            cwd=HERE,
            bufsize=0,
            env={**os.environ, **env_vars},
        )

    def send(self, obj: dict) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write(json.dumps(obj).encode() + b"\n")
        self.proc.stdin.flush()

    def recv(self) -> dict | None:
        """One outbound line; None on EOF."""
        assert self.proc.stdout is not None
        fd = self.proc.stdout.fileno()
        deadline = time.monotonic() + READ_TIMEOUT_S
        while True:
            nl = self.buf.find(b"\n")
            if nl >= 0:
                line, self.buf = self.buf[:nl], self.buf[nl + 1:]
                break
            if self.proc.poll() is not None:
                r, _, _ = select.select([fd], [], [], 0)
                if not r:
                    line = self.buf
                    self.buf = b""
                    return None if not line else json.loads(line)
            else:
                r, _, _ = select.select(
                    [fd], [], [], max(0.0, deadline - time.monotonic())
                )
                if not r:
                    raise RuntimeError(
                        f"agent silent for {READ_TIMEOUT_S:.0f}s — wire wedged"
                    )
            chunk = os.read(fd, 65536)
            if not chunk:
                line, self.buf = self.buf, b""
                if not line:
                    return None
                break
            self.buf += chunk
        return json.loads(line)

    def close(self) -> None:
        if self.proc.stdin is not None and self.proc.poll() is None:
            try:
                self.proc.stdin.close()
            except BrokenPipeError:
                pass
        try:
            self.proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()


def drive(agent: Agent, env, turns: list[str], max_steps: int) -> list[dict]:
    """Answer every outbound call with the real airline tool, every say with
    the next scripted user turn. Returns the outbound transcript."""
    from tau2.data_model.message import ToolCall

    log: list[dict] = []
    next_turn = 0
    steps = 0
    while steps < max_steps:
        steps += 1
        obj = agent.recv()
        if obj is None:
            log.append({"kind": "eof"})
            print("--- agent EOF")
            break
        log.append(obj)
        if obj["kind"] == "call":
            print(f"  > call {obj['id']} {obj['name']} {json.dumps(obj.get('arguments'))}")
            msg = env.get_response(
                ToolCall(id=obj["id"], name=obj["name"],
                         arguments=obj.get("arguments") or {})
            )
            agent.send({"kind": "result", "id": obj["id"],
                        "content": msg.content or "",
                        "error": bool(msg.error)})
            continue
        # say
        print(f"  < say: {str(obj.get('text'))[:400]}")
        if next_turn < len(turns):
            agent.send({"kind": "user", "text": turns[next_turn]})
            next_turn += 1
        else:
            agent.close()
            break
    return log


def survey(receipt_dir: Path) -> dict:
    """Read back what the gate recorded and what the model then saw."""
    fired: dict[str, list[int]] = {}
    guide_texts: dict[str, str] = {}
    sightings: list[dict] = []
    duplicate_keys: list[str] = []

    for p in sorted(receipt_dir.glob("callsteps_*.jsonl")):
        for line in p.read_text().splitlines():
            rec = json.loads(line)
            keys = rec.get("fired_guides") or []
            for k in keys:
                if k in fired:
                    duplicate_keys.append(k)
                fired.setdefault(k, []).append(rec.get("seq"))
            sid = rec.get("seq")
            # the guide text the gate rendered for this dispatch
            report = rec.get("report") or rec.get("trace") or ""
            for m in re.finditer(r"guide ([^:]+): ", report):
                guide_texts[m.group(1)] = True
            if keys:
                sightings.append({
                    "seq": sid, "verb": rec.get("verb"),
                    "branch": rec.get("branch"), "origin": rec.get("origin"),
                    "fired_guides": keys, "file": p.name,
                })

    # Model-visible channel: every later request body embeds the observed
    # transcript. A guide that reached the model appears verbatim here.
    reached_model: list[dict] = []
    for p in sorted(receipt_dir.glob("call_*.json")):
        body = json.loads(p.read_text())
        blob = json.dumps(body)
        hits = sorted(set(re.findall(r"guide ([a-z*][^:\\\\]*?) \\?: ", blob)))
        plain = sorted(set(re.findall(r"guide ([a-z*\-][\w>*\\-]*): ", blob)))
        for key in plain:
            reached_model.append({"request": p.name, "key": key})
    return {
        "fired_guides": {k: v for k, v in sorted(fired.items())},
        "sightings": sightings,
        "guide_texts_in_report": sorted(guide_texts),
        "reached_model_channel": reached_model,
        "once_per_session_violations": duplicate_keys,
    }


def main() -> int:
    ap = argparse.ArgumentParser(prog="live_guides_smoke.py")
    ap.add_argument("--model", default=os.environ.get("KOPIUM_MODEL", "qwen2.5-coder:14b"))
    ap.add_argument("--endpoint",
                    default=os.environ.get("KOPIUM_API_URL",
                                           "http://localhost:11434/v1/chat/completions"))
    ap.add_argument("--turn", action="append", default=[])
    ap.add_argument("--policy", default="", help="domain policy text (empty = tau2 airline policy)")
    ap.add_argument("--receipt-dir", default="")
    ap.add_argument("--max-steps", type=int, default=24)
    args = ap.parse_args()

    if not _local_only(args.endpoint):
        sys.exit(f"refused: {args.endpoint} is not a local endpoint — this smoke is $0 only")
    if not AGENT_PIN.exists():
        sys.exit(f"agent binary missing: {AGENT_PIN} (run bench/build-airline-gate.sh)")

    from tau2.runner import build_environment

    env = build_environment("airline")
    policy = args.policy or env.get_policy()
    turns = args.turn or [
        "Hi, I'm emma_kim_9957. Please pull up my account details.",
        "Now my most recent reservation, with its flights.",
        "Thanks, that's all.",
    ]

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    receipt_dir = Path(args.receipt_dir) if args.receipt_dir else (
        HERE / "results" / "localsmoke" / stamp / "receipts"
    )
    receipt_dir.mkdir(parents=True, exist_ok=True)

    print(f"model    : {args.model}")
    print(f"endpoint : {args.endpoint}")
    print(f"receipts : {receipt_dir}")
    print(f"turns    : {len(turns)}")
    print()

    agent = Agent(AGENT_PIN, {
        "KOPIUM_MODEL": args.model.removeprefix("openrouter/"),
        "KOPIUM_API_URL": args.endpoint,
        "OPENROUTER_API_KEY": os.environ.get("OPENROUTER_API_KEY", "local-dummy"),
        "KOPIUM_RECEIPT_DIR": str(receipt_dir),
        "KOPIUM_REASONING": os.environ.get("KOPIUM_REASONING", "none"),
    })
    try:
        agent.send({"kind": "init", "policy": policy})
        agent.send({"kind": "user", "text": turns[0]})
        log = drive(agent, env, turns[1:], args.max_steps)
    finally:
        agent.close()

    report = survey(receipt_dir)
    report["model"] = args.model
    report["endpoint"] = args.endpoint
    report["receipt_dir"] = str(receipt_dir)
    report["outbound"] = log
    (receipt_dir.parent / "summary.json").write_text(json.dumps(report, indent=1))

    print()
    print("=" * 60)
    print(f"fired_guides keys : {sorted(report['fired_guides'])}")
    print(f"fires per key     : {report['fired_guides']}")
    print(f"reached model     : {sorted({r['key'] for r in report['reached_model_channel']})}")
    print(f"report texts      : {report['guide_texts_in_report']}")
    print(f"once-per-session  : {'VIOLATION ' + str(report['once_per_session_violations']) if report['once_per_session_violations'] else 'clean'}")
    print(f"summary           : {receipt_dir.parent / 'summary.json'}")
    ok = bool(report["fired_guides"])
    print(f"VERDICT: {'guides FIRED' if ok else 'NO GUIDES FIRED'}")
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
