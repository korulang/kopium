#!/usr/bin/env python3
"""
user_driver — a human plays the USER.

Spawns bench/tau-agent-binary (the model-driven agent: a real model emits
wire, std/bridge enforces the scope) and sits on the seat the bench
marshal normally occupies — the human reads what the agent says and
replies, one line at a time. For scopes whose verbs are real tors (db:
sqlite executes in-binary) there is no environment to impersonate; a
stray `call` line means the vocabulary leaked a marshal verb and gets an
error result so the binary never wedges.

Boot: sends init (the domain policy — rules the model judges its work
against, rendered into the system message) then one user line — the goal.
From there the model works until it says something, and each SAY owes
your reply.

In on stdin, one JSON object per line:
  {"do":"user","text":"<reply>"}   — answer a say() / talk to the agent
  {"do":"quit"}                    — close the session

Out from the process:
  SAY:      what the agent told the user (owes your reply)
  CALL:     a marshal verb escaped the scope — error-resulted
  anything on stderr is the binary's own log (wire> lines = the model's
  raw programs) and is passed through tagged.

Env for the spawned binary:
  KOPIUM_SCOPE (--scope, default db), KOPIUM_MODEL (--model, required —
  no default: the harness names the agent model), KOPIUM_RECEIPT_DIR
  (--receipts, required — the request/response trail), KOPIUM_REASONING
  and OPENROUTER_API_KEY pass through from your environment.

Usage:
  KOPIUM_MODEL=poolside/laguna-s-2.1:free python3 user_driver.py \
      --scope db --goal "Make a table called pets with columns id and name."
"""

from __future__ import annotations

import argparse
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent

DEFAULT_POLICY = (
    "You are operating a sqlite database for the user. Do exactly what "
    "they ask — read before writing, run only the SQL their request "
    "implies, step or finish every stream you open, and close the "
    "connection when the task is done. If a request is ambiguous or "
    "impossible, say() what is missing instead of guessing."
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", default=str(HERE / "tau-agent-binary"))
    ap.add_argument("--scope", default="db")
    ap.add_argument("--model", default=os.environ.get("KOPIUM_MODEL", ""),
                    help="OpenRouter slug — required (or set KOPIUM_MODEL)")
    ap.add_argument("--goal", default="",
                    help="first user line; prompted for if empty")
    ap.add_argument("--policy", default=DEFAULT_POLICY,
                    help="init policy text riding the system message")
    ap.add_argument("--receipts", default="",
                    help="KOPIUM_RECEIPT_DIR (default: receipts/user-<ts>)")
    args = ap.parse_args()

    if not args.model:
        print("user_driver: --model or KOPIUM_MODEL required "
              "(the harness names the agent model)", flush=True)
        sys.exit(2)

    receipts = Path(args.receipts or
                    HERE / "receipts" / f"user-{int(time.time())}")
    receipts.mkdir(parents=True, exist_ok=True)

    spawn_env = dict(os.environ)
    spawn_env["KOPIUM_SCOPE"] = args.scope
    spawn_env["KOPIUM_MODEL"] = args.model
    spawn_env["KOPIUM_RECEIPT_DIR"] = str(receipts)

    proc = subprocess.Popen(
        [args.binary],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, cwd=HERE, bufsize=0, env=spawn_env,
    )

    def send(obj: dict) -> None:
        proc.stdin.write(json.dumps(obj).encode() + b"\n")
        proc.stdin.flush()

    print(f"=== user_driver: scope={args.scope} model={args.model} "
          f"receipts={receipts} ===", flush=True)
    print('Type {"do":"user","text":"..."} to answer; '
          '{"do":"quit"} to end.', flush=True)

    send({"kind": "init", "policy": args.policy})
    goal = args.goal or input("first goal> ").strip()
    send({"kind": "user", "text": goal})

    out_fd = proc.stdout.fileno()
    err_fd = proc.stderr.fileno()
    stdin_fd = sys.stdin.fileno()
    out_buf, err_buf, in_buf = b"", b"", b""
    say_owed = 0

    while True:
        if proc.poll() is not None:
            rest = proc.stderr.read() or b""
            sys.stderr.write(rest.decode(errors="replace"))
            print(f"=== binary exited rc={proc.returncode} "
                  f"— receipts in {receipts} ===", flush=True)
            return
        r, _, _ = select.select([out_fd, err_fd, stdin_fd], [], [])
        for fd in r:
            if fd == stdin_fd:
                chunk = os.read(stdin_fd, 65536)
                if not chunk:
                    proc.stdin.close()
                    continue
                in_buf += chunk
                while b"\n" in in_buf:
                    line, in_buf = in_buf.split(b"\n", 1)
                    if not line.strip():
                        continue
                    try:
                        cmd = json.loads(line)
                    except json.JSONDecodeError:
                        print(f"!! not json: {line[:200]!r}", flush=True)
                        continue
                    do = cmd.get("do")
                    if do == "user":
                        say_owed = max(0, say_owed - 1)
                        send({"kind": "user", "text": cmd.get("text", "")})
                    elif do == "quit":
                        proc.stdin.close()
                        return
                    else:
                        print(f"!! unknown do: {do}", flush=True)
            elif fd == err_fd:
                chunk = os.read(err_fd, 65536)
                if not chunk:
                    continue
                err_buf += chunk
                while b"\n" in err_buf:
                    line, err_buf = err_buf.split(b"\n", 1)
                    sys.stderr.write(f"  | {line.decode(errors='replace')}\n")
                    sys.stderr.flush()
            else:
                chunk = os.read(out_fd, 65536)
                if not chunk:
                    continue
                out_buf += chunk
                while b"\n" in out_buf:
                    raw, out_buf = out_buf.split(b"\n", 1)
                    try:
                        obj = json.loads(raw)
                    except json.JSONDecodeError:
                        print(f"!! non-JSON from binary: {raw[:300]!r}",
                              flush=True)
                        continue
                    kind = obj.get("kind")
                    if kind == "say":
                        say_owed += 1
                        print(f"SAY: {obj['text']}   "
                              f"[owes user reply #{say_owed}]", flush=True)
                    elif kind == "call":
                        # A db-scope tor never emits call — this is a leak.
                        print(f"CALL (leak!) {obj.get('name')}", flush=True)
                        send({"kind": "result", "id": obj["id"],
                              "content": "no tau2 environment — this scope "
                                         "is self-dispatched",
                              "error": True})
                    else:
                        print(f"!! {kind}: {raw[:300]!r}", flush=True)


if __name__ == "__main__":
    main()
