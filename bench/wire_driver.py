#!/usr/bin/env python3
"""
wire_driver — a human plays the agent.

Spawns bench/wire-repl-binary (tau-agent's bridge/surface with stdin where
the model call sits), routes its `call` lines through the REAL tau2
environment via env.get_response — the same function the orchestrator
uses, so result text is byte-identical to the bench — and hands the
program-writing to whoever is at stdin.

Boot prints the task instruction (the user-simulator's script — you are
the user now). Then, one JSON object per line on stdin:

  {"do":"wire","text":"<program>"}  — run a program through the bridge
  {"do":"user","text":"<reply>"}    — a user message / answer a say()
  {"do":"hash"}                     — print the environment db hash
  {"do":"quit"}                     — close the session

Out from the process: GRAMMAR once, then
  SAY:      text the agent sent to the user (owes a user reply)
  CALL:     tool invocation as the env sees it
  RESULT:   what the env answered (verbatim, truncated for display)
  REPORT:   the bridge's turn verdict — what the model would observe
  HEARD:    a user line the pend queue captured
  READY:    turn ended; send the next line

Usage: ../../tau2-bench/.venv/bin/python wire_driver.py --task 23
"""

from __future__ import annotations

import argparse
import json
import os
import select
import subprocess
import sys
from copy import deepcopy
from pathlib import Path

from tau2.data_model.message import ToolCall
from tau2.runner import build_environment, get_tasks

HERE = Path(__file__).parent


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", default="23")
    ap.add_argument("--domain", default="airline")
    ap.add_argument("--binary", default=str(HERE / "wire-repl-binary"))
    ap.add_argument("--grammar-out", default="",
                    help="write the boot grammar to this file instead of stdout")
    args = ap.parse_args()

    env = build_environment(args.domain)
    task = get_tasks(args.domain, task_ids=[args.task])[0]
    ist = task.initial_state
    env.set_state(
        initialization_data=ist.initialization_data if ist else None,
        initialization_actions=ist.initialization_actions if ist else None,
        message_history=(
            deepcopy(ist.message_history)
            if ist and ist.message_history else []
        ),
    )

    print(f"=== task {task.id} ===\n{task.description or ''}\n"
          f"=== user_scenario (your script as the user) ===\n"
          f"{task.user_scenario or '(none)'}\n=== end ===",
          flush=True)

    err_log = open("/tmp/wrepl_err.txt", "w")
    proc = subprocess.Popen(
        [args.binary],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=err_log,
        cwd=HERE, bufsize=0,
    )

    def send(obj: dict) -> None:
        proc.stdin.write(json.dumps(obj).encode() + b"\n")
        proc.stdin.flush()

    send({"kind": "init", "policy": env.get_policy()})
    buf = b""
    in_buf = b""
    say_owed = 0
    bin_fd = proc.stdout.fileno()
    stdin_fd = sys.stdin.fileno()
    grammar_shown = False

    while True:
        if proc.poll() is not None:
            err_log.flush()
            err = Path("/tmp/wrepl_err.txt").read_text(errors="replace")
            print(f"=== binary exited rc={proc.returncode} ===\n{err[-2000:]}",
                  flush=True)
            return
        r, _, _ = select.select([bin_fd, stdin_fd], [], [])
        for fd in r:
            if fd == stdin_fd:
                chunk = os.read(stdin_fd, 65536)
                if not chunk:
                    print("=== stdin EOF — closing binary ===", flush=True)
                    proc.stdin.close()
                    return
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
                    if do == "wire":
                        send({"kind": "wire", "text": cmd.get("text", "")})
                    elif do == "user":
                        say_owed = max(0, say_owed - 1)
                        send({"kind": "user", "text": cmd.get("text", "")})
                    elif do == "hash":
                        print(f"HASH: {env.get_db_hash()}", flush=True)
                    elif do == "quit":
                        proc.stdin.close()
                        return
                    else:
                        print(f"!! unknown do: {do}", flush=True)
            else:
                chunk = os.read(bin_fd, 65536)
                if not chunk:
                    continue
                buf += chunk
                while b"\n" in buf:
                    raw, buf = buf.split(b"\n", 1)
                    try:
                        obj = json.loads(raw)
                    except json.JSONDecodeError:
                        print(f"!! non-JSON from binary: {raw[:200]!r}", flush=True)
                        continue
                    kind = obj.get("kind")
                    if kind == "grammar":
                        if args.grammar_out:
                            Path(args.grammar_out).write_text(obj["text"])
                            print(f"GRAMMAR -> {args.grammar_out}", flush=True)
                        else:
                            print(f"=== GRAMMAR ===\n{obj['text']}\n=== END GRAMMAR ===",
                                  flush=True)
                        grammar_shown = True
                    elif kind == "say":
                        say_owed += 1
                        print(f"SAY: {obj['text']}   [owes user reply #{say_owed}]",
                              flush=True)
                    elif kind == "call":
                        print(f"CALL {obj['name']}({json.dumps(obj['arguments'])})",
                              flush=True)
                        tm = env.get_response(ToolCall(
                            id=obj["id"], name=obj["name"],
                            arguments=obj.get("arguments") or {},
                        ))
                        content = tm.content or ""
                        disp = content if len(content) < 600 else content[:600] + "…"
                        print(f"RESULT {obj['id']}: {disp}", flush=True)
                        send({"kind": "result", "id": obj["id"], "content": content})
                    elif kind == "report":
                        print(f"REPORT: {obj['text']}", flush=True)
                        if "abandoned" in obj["text"]:
                            print("=== ABANDONED — session over ===", flush=True)
                            proc.stdin.close()
                            return
                    elif kind == "heard":
                        print(f"HEARD: {obj['text']}", flush=True)
                    elif kind == "bad":
                        print(f"BAD: {obj['text']}", flush=True)
                    elif kind == "ready":
                        print(f"READY (say replies owed: {say_owed})", flush=True)
                    else:
                        print(f"!! unknown kind: {raw[:300]!r}", flush=True)


if __name__ == "__main__":
    main()
