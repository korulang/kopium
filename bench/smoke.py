#!/usr/bin/env python3
"""
Smoke gate for the kopium arm — must PASS before measure.py sweeps kopium.

  python3 bench/smoke.py               # run the smoke tasks (n=1 each) on the
                                       # current tau-agent-binary, then check
  python3 bench/smoke.py --check DIR…  # check existing kopium run dirs only

What it asserts (functionality, not reward — a 0.0 run can pass smoke):
  1. every run completes and its session.json agrees with its receipts
     (measure.metrics raises otherwise);
  2. INTEGRITY: every tool result tau2 returned reached the model intact —
     for each ToolMessage, if any model call happened after it, some receipt
     (an exact request body) contains its full content;
  3. COVERAGE, deterministic and zero-spend (bench/verb-check.sh): every
     airline verb's real proc emits its call with the tau2 name and the
     fixture's arguments, and binds the fed result intact (one fed result is
     >11 KB). Which verbs the model happens to choose in the smoke runs is
     reported, not gated — model choice is not core functionality.

On PASS it writes results/measure/smoke-<kopium config key>.json, which
measure.py requires before running the kopium arm on that exact binary.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import measure  # noqa: E402

# Chosen from tool usage in cached stock trajectories + golden actions:
#  2: list_all_airports, search_onestop_flight (large results)
# 13: transfer_to_human_agents
# 14: book_reservation, cancel_reservation, calculate, search_onestop_flight
# 18: update_reservation_baggages/flights, calculate, both searches
# 40: update_reservation_passengers
SMOKE_TASKS = ["2", "13", "14", "18", "40"]
TOOLS = {
    "book_reservation", "calculate", "cancel_reservation", "get_flight_status",
    "get_reservation_details", "get_user_details", "list_all_airports",
    "search_direct_flight", "search_onestop_flight", "send_certificate",
    "transfer_to_human_agents", "update_reservation_baggages",
    "update_reservation_flights", "update_reservation_passengers",
}


def check_run(d: Path) -> tuple[list[str], set[str]]:
    """Returns (failures, tools called) for one kopium run dir."""
    fails = measure.integrity_failures(d)
    if not fails:
        measure.metrics("kopium", d)  # completion + session/receipt consistency
    sim = json.loads((d / "sim.json").read_text())
    called = {tc["name"] for m in sim["messages"] for tc in (m.get("tool_calls") or [])}
    return fails, called


def verb_check() -> list[str]:
    """Deterministic, zero-spend: every verb's real proc marshals its call and
    its result comes back intact (bench/verb-check.sh). Checks the captured
    outbound calls against the fixture and each bound value against the
    canned result fed for it."""
    rc = subprocess.run(["sh", str(HERE / "verb-check.sh")], cwd=HERE,
                        capture_output=True, text=True)
    if rc.returncode != 0:
        return [f"verb-check.sh exited {rc.returncode}: {rc.stderr[-400:]}"]
    out = HERE / "results" / "verb-check"
    fixture = [json.loads(l) for l in (HERE / "verb-check.fixture.jsonl").read_text().splitlines() if l.strip()]
    fed = [json.loads(l) for l in (HERE / "verb-check.stdin.jsonl").read_text().splitlines() if l.strip()]
    outbound = [json.loads(l) for l in (out / "outbound.jsonl").read_text().splitlines() if l.strip()]
    lines = (out / "values.txt").read_text().splitlines()
    values = [json.loads(l[len("VALUE "):]) for l in lines if l.startswith("VALUE ")]
    fails = [f"verb-check: {l}" for l in lines if l.startswith("FAIL")]
    if not (len(fixture) == len(fed) == len(outbound) == len(values)):
        return fails + [f"verb-check: counts differ fixture={len(fixture)} fed={len(fed)} "
                        f"outbound={len(outbound)} values={len(values)}"]
    for fx, fd, ob, val in zip(fixture, fed, outbound, values):
        v = fx["verb"]
        if fx["tau_name"] is None:  # say
            if ob.get("kind") != "say" or ob.get("text") != fx["args"]["text"]:
                fails.append(f"verb-check {v}: outbound {ob}")
            if val.get("value") != fd["text"]:
                fails.append(f"verb-check {v}: bound {val.get('value')!r} != user reply {fd['text']!r}")
            continue
        if ob.get("kind") != "call" or ob.get("name") != fx["tau_name"]:
            fails.append(f"verb-check {v}: expected call {fx['tau_name']}, got {ob.get('kind')} {ob.get('name')}")
        if ob.get("arguments") != fx["args"]:
            fails.append(f"verb-check {v}: arguments {ob.get('arguments')} != {fx['args']}")
        if fd.get("id") != ob.get("id"):
            fails.append(f"verb-check {v}: fed id {fd.get('id')} != call id {ob.get('id')}")
        if val.get("value") != fd["content"]:
            fails.append(f"verb-check {v}: bound value ({len(str(val.get('value')))} bytes) "
                         f"!= fed result ({len(fd['content'])} bytes)")
    covered = {fx["tau_name"] for fx in fixture if fx["tau_name"]}
    for t in sorted(TOOLS - covered):
        fails.append(f"verb-check: fixture has no line for {t}")
    return fails


def check(dirs: list[Path]) -> bool:
    fails: list[str] = verb_check()
    called: set[str] = set()
    for d in dirs:
        try:
            f, c = check_run(d)
        except Exception as e:  # noqa: BLE001
            f, c = [f"{d.relative_to(HERE)}: {e}"], set()
        fails += f
        called |= c
    uncovered = TOOLS - called
    for f in fails:
        print("FAIL " + f)
    if uncovered:
        print(f"note: the model did not choose {sorted(uncovered)} in these runs; "
              f"their marshal path is covered by the deterministic verb check")
    print(f"smoke: {'PASS' if not fails else 'FAIL'} — {len(dirs)} runs, "
          f"{len(called)}/{len(TOOLS)} tools called, {len(fails)} failures")
    return not fails


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", nargs="*", type=Path)
    a = ap.parse_args()
    if a.check is not None:
        sys.exit(0 if check([p.resolve() for p in a.check]) else 1)

    key, _ = measure.config_key("kopium")
    dirs = []
    for tid in SMOKE_TASKS:
        d = measure.run_dir("kopium", key, tid, 0)
        if not (d / "sim.json").exists():
            print("  " + measure.run_one("kopium", key, tid, 0), flush=True)
        dirs.append(d)
    ok = check([d for d in dirs if (d / "sim.json").exists()]) and all(
        (d / "sim.json").exists() for d in dirs)
    if ok:
        (measure.OUT / f"smoke-{key}.json").write_text(json.dumps(
            {"key": key, "tasks": SMOKE_TASKS, "verdict": "PASS"}, indent=1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
