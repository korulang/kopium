#!/usr/bin/env python3
"""corpus-replay.py — replay recorded wire programs through the real bridge.

Extracts every assistant turn's wire source from the receipts in
results/runs/<run>/receipts/call_*.json (the last call carries the full
message history), then replays each run's programs — in order — through
corpus-replay-binary under each scope.

The procs' outbound protocol lines are answered reactively:
  {"kind":"call","id":X,...} -> {"kind":"result","id":X,"content":"{}"}
  {"kind":"say",...}         -> {"kind":"user","text":"ok"}
so no canned stdin ordering is needed. One process per (run, scope): the
handle pool lives and dies exactly as one conversation does.

Usage: python3 corpus-replay.py [--scopes airline,airline-native]
Writes results/corpus-replay/<scope>/<run>.outcomes.jsonl and a summary.
"""
import json, glob, os, subprocess, sys, collections
from pathlib import Path

HERE = Path(__file__).parent
BIN = HERE / "corpus-replay-binary"
OUT = HERE / "results" / "corpus-replay"
SCOPES = ["airline", "airline-native"]


def run_programs(run_dir: Path) -> list[str]:
    """The run's wire programs in emission order (last receipt = full history)."""
    receipts = sorted(run_dir.glob("receipts/call_*.json"))
    if not receipts:
        return []
    msgs = json.loads(receipts[-1].read_text())["messages"]
    progs = []
    for m in msgs:
        if m.get("role") != "assistant":
            continue
        c = m.get("content")
        if c and c.strip():
            progs.append(c)
        for tc in m.get("tool_calls") or []:
            try:
                args = json.loads(tc["function"]["arguments"])
            except (json.JSONDecodeError, KeyError):
                continue
            if "program" in args:
                progs.append(args["program"])
    return progs


def replay(scope: str, progs: list[str]) -> tuple[list[str], list[str]]:
    """Run one fixture file through the binary; returns (outcomes, calls)."""
    fixture = HERE / "corpus-replay.fixture.jsonl"
    fixture.write_text(
        "".join(json.dumps({"source": p}) + "\n" for p in progs))
    proc = subprocess.Popen(
        [str(BIN)],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, cwd=HERE,
        env={**os.environ, "KOPIUM_SCOPE": scope},
        text=True, bufsize=1)
    outcomes, calls = [], []
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line.startswith('{"kind":"call"'):
            cid = json.loads(line)["id"]
            calls.append(line)
            proc.stdin.write(json.dumps(
                {"kind": "result", "id": cid, "content": "{}"}) + "\n")
            proc.stdin.flush()
        elif line.startswith('{"kind":"say"'):
            proc.stdin.write('{"kind":"user","text":"ok"}\n')
            proc.stdin.flush()
        else:
            outcomes.append(line)
    proc.stdin.close()
    proc.wait()
    return outcomes, calls


def main():
    runs = sorted(d for d in (HERE / "results" / "runs").iterdir()
                  if (d / "receipts").is_dir())
    print(f"{len(runs)} recorded runs")
    for scope in SCOPES:
        hist = collections.Counter()
        scope_out = OUT / scope
        scope_out.mkdir(parents=True, exist_ok=True)
        n_prog = 0
        for rd in runs:
            progs = run_programs(rd)
            if not progs:
                continue
            n_prog += len(progs)
            outcomes, calls = replay(scope, progs)
            (scope_out / f"{rd.name}.jsonl").write_text(
                "\n".join(outcomes) + "\n")
            for o in outcomes:
                hist[o.split(" ", 1)[0]] += 1
            (scope_out / f"{rd.name}.calls.jsonl").write_text(
                "\n".join(calls) + ("\n" if calls else ""))
        print(f"\n== {scope}: {n_prog} programs across runs ==")
        for k, v in hist.most_common():
            print(f"  {v:4d}  {k}")


if __name__ == "__main__":
    main()
