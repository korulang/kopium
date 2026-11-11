#!/usr/bin/env python3
"""check_split.py — the test-20 exposure gate.

bench/split/test-20.txt is the frozen holdout (see bench/split/SPLIT.md).
Every run that can see a test-20 task — its transcript, its gold, its
db_check — must first appear in bench/split/exposure-ledger.jsonl, one
JSON object per line: {date, task_ids, binary_hash, purpose, who_looked}.
This script is that ledger's only writer and its check. Reading a test
transcript counts as an exposure (methodology §4.2).

  python3 bench/check_split.py gate 0 1 2
  python3 bench/check_split.py gate --tasks-file ids.txt
  python3 bench/check_split.py gate --cmd "python3 bench/run_airline.py 2"
  python3 bench/check_split.py record --purpose "<why>" --who "<who>" 2 6
  python3 bench/check_split.py record --purpose "<why>" --who "<who>" \
      --binary bench/airline-gate-binary --cmd "python3 bench/measure.py --ids 2"

gate exits 1 when any test-20 id lacks a ledger line, or when the
invocation's task selection cannot be resolved — opaque selectors refuse
rather than guess. record appends one ledger line and exits 0.

KOPIUM_EXPOSURE_LEDGER overrides the ledger path (self-test only).

Limits, stated plainly: the gate sees task ids where the invocation
names them. Browsing saved results (tau2 view, bench/results/**/task2/)
names no id — that exposure is honor-system and must be recorded by hand.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import sys
from datetime import date
from pathlib import Path

BENCH = Path(__file__).parent
SPLIT_DIR = BENCH / "split"
TRAIN_FILE = SPLIT_DIR / "train-30.txt"
TEST_FILE = SPLIT_DIR / "test-20.txt"
DEFAULT_LEDGER = SPLIT_DIR / "exposure-ledger.jsonl"

# Bench entry points whose first positional arg is the airline task id.
_SINGLE_ID_SCRIPTS = {
    "run_airline.py",
    "run_airline_local.py",
    "run_baseline.py",
    "run_stock.py",
}
# Bench entry points that take --ids <csv> (measure.py requires it;
# run_compare.py falls back to an unresolvable positional range/all-50).
_IDS_FLAG_SCRIPTS = {"measure.py", "run_compare.py"}
_WIRE_DRIVER = "wire_driver.py"  # --task ID, --domain, --bare
# Mock-domain runners: different id space, not the airline holdout.
_MOCK_SCRIPTS = {
    "run_mock.py",
    "run_mock_local.py",
    "run_mock_traj.py",
    "run_all_mock.py",
}
_TAU2 = "tau2"
_SEPARATORS = {"&&", "||", ";", "|"}
_TAU2_RUN_SUBCOMMANDS = {"run", "review"}


def _ledger_path() -> Path:
    return Path(os.environ.get("KOPIUM_EXPOSURE_LEDGER", DEFAULT_LEDGER))


def read_ids(path: Path) -> list[str]:
    """Ids from a split-format file: one per line, # comments and blanks ok."""
    ids: list[str] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        ids.extend(p for p in line.replace(",", " ").split() if p)
    return ids


def split_ids(name: str) -> frozenset[str]:
    return frozenset(read_ids(SPLIT_DIR / name))


def test_ids() -> frozenset[str]:
    return split_ids("test-20.txt")


def covered_ids() -> set[str]:
    """Every task id with at least one ledger line. A corrupt ledger line
    is a loud error — silently skipping it could hide an exposure."""
    ledger = _ledger_path()
    out: set[str] = set()
    if not ledger.exists():
        return out
    for n, line in enumerate(ledger.read_text().splitlines(), 1):
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError as e:
            raise SystemExit(f"exposure ledger line {n} is not JSON: {e}")
        out.update(str(t) for t in entry.get("task_ids", []))
    return out


def uncovered(ids: set[str]) -> list[str]:
    """Test-20 ids in `ids` that no ledger line covers, sorted numerically."""
    covered = covered_ids()
    bad = sorted((ids & test_ids()) - covered,
                 key=lambda s: (0, int(s)) if s.isdigit() else (1, s))
    return bad


def _pieces(token: str) -> list[str]:
    """Candidate id fragments inside one argv token: comma-splits and
    strips a leading --flag= prefix."""
    out: list[str] = []
    for part in token.split(","):
        if "=" in part:
            part = part.split("=", 1)[1]
        out.append(part)
    return out


def _generic_scan(tokens: list[str]) -> set[str]:
    """Last-resort scan for segments with no known selector: any bare
    numeric token that could be an airline task id. False positives
    (e.g. --trials 2) refuse loud — re-run with --tasks for precision."""
    ids: set[str] = set()
    for t in tokens:
        for p in _pieces(t):
            if p.isdigit():
                ids.add(p)
    return ids


def _flag_value(tokens: list[str], start: int, name: str) -> str | None:
    """Value of --name at/after `start`: '--name v' or '--name=v'."""
    for j in range(start, len(tokens)):
        t = tokens[j]
        if t == name:
            return tokens[j + 1] if j + 1 < len(tokens) else None
        if t.startswith(name + "="):
            return t.split("=", 1)[1]
    return None


def _tau2_ids(tokens: list[str], i: int) -> tuple[set[str], list[str]]:
    """Task exposure of a `tau2 ...` segment starting at token i."""
    ids: set[str] = set()
    opaque: list[str] = []
    domain = _flag_value(tokens, i + 1, "--domain")
    if domain and domain != "airline":
        return ids, opaque

    rest = tokens[i + 1 :]
    sub = next((t for t in rest if not t.startswith("-")), None)

    task_ids: list[str] = []
    j = 0
    while j < len(rest):
        t = rest[j]
        if t == "--task-ids":
            k = j + 1
            while k < len(rest) and not rest[k].startswith("-"):
                task_ids.extend(_pieces(rest[k]))
                k += 1
            j = k
            continue
        if t.startswith("--task-ids="):
            task_ids.extend(_pieces(t.split("=", 1)[1]))
        j += 1
    task_ids = [p for p in task_ids if p.isdigit()]

    split_name = _flag_value(rest, 0, "--task-split-name")
    has_num_tasks = any(
        t == "--num-tasks" or t.startswith("--num-tasks=") for t in rest
    )
    running = (
        sub in _TAU2_RUN_SUBCOMMANDS
        or bool(task_ids)
        or split_name is not None
        or has_num_tasks
        or "--domain" in rest
    )
    if not running:
        return ids, opaque  # view/domain/check-data/help: no task selection
    if sub == "play":
        opaque.append(
            "tau2 play selects the split interactively — the gate cannot "
            "resolve it; use `tau2 run --task-ids ...` instead"
        )
        return ids, opaque
    if task_ids:
        ids.update(task_ids)
    elif split_name == "train":
        pass  # any prefix of train is still train
    elif has_num_tasks:
        opaque.append(
            "tau2 --num-tasks truncates a split prefix whose order the gate "
            "cannot verify — re-run with --task-ids <csv>"
        )
    else:
        # base is the default split and base ⊇ test; an explicit `test`
        # split or an unknown split name is treated the same — loud.
        ids.update(test_ids())
    return ids, opaque


def _selector_ids(tokens: list[str], i: int) -> tuple[set[str], list[str]]:
    """Exposure of the known bench/tau2 selector at token i."""
    base = tokens[i].rsplit("/", 1)[-1]
    ids: set[str] = set()
    opaque: list[str] = []
    rest = tokens[i + 1 :]

    if base in _SINGLE_ID_SCRIPTS:
        # argv[1] is the task id for these scripts; flags mean the default.
        if rest and not rest[0].startswith("-"):
            ids.update(p for p in _pieces(rest[0]) if p.isdigit())
    elif base in _IDS_FLAG_SCRIPTS:
        found = False
        for j, t in enumerate(rest):
            if t == "--ids":
                found = True
                if j + 1 < len(rest):
                    ids.update(p for p in _pieces(rest[j + 1]) if p.isdigit())
                break
            if t.startswith("--ids="):
                found = True
                ids.update(
                    p for p in _pieces(t.split("=", 1)[1]) if p.isdigit()
                )
                break
        if not found and base == "run_compare.py":
            opaque.append(
                "run_compare.py without --ids selects by positional "
                "start/count or all 50 tasks — the gate cannot resolve "
                "it; re-run with --ids <csv>"
            )
    elif base == _WIRE_DRIVER:
        if "--bare" not in rest:
            domain = _flag_value(rest, 0, "--domain")
            task = _flag_value(rest, 0, "--task")
            if not (domain and domain != "airline") and task:
                ids.update(p for p in _pieces(task) if p.isdigit())
    elif base == _TAU2:
        return _tau2_ids(tokens, i)
    # _MOCK_SCRIPTS: different domain, no airline exposure.
    return ids, opaque


def resolve_cmd(cmd: str) -> tuple[set[str], list[str]]:
    """Task ids a shell command can expose, plus reasons it cannot be
    resolved. Segments split on && || ; | and newlines; a segment with a
    known selector uses that selector's grammar, anything else gets the
    conservative numeric scan."""
    ids: set[str] = set()
    opaque: list[str] = []
    known = _SINGLE_ID_SCRIPTS | _IDS_FLAG_SCRIPTS | {_WIRE_DRIVER, _TAU2}

    for line in cmd.splitlines():
        try:
            tokens = shlex.split(line)
        except ValueError:
            tokens = line.split()
        # `bash -c "..."` style: re-split tokens that still hold spaces.
        flat: list[str] = []
        for t in tokens:
            flat.extend(t.split() if " " in t else [t])
        # split into segments on shell separators
        seg: list[str] = []
        segments: list[list[str]] = []
        for t in flat:
            if t in _SEPARATORS:
                if seg:
                    segments.append(seg)
                    seg = []
            else:
                seg.append(t)
        if seg:
            segments.append(seg)

        for seg_tokens in segments:
            hits = [
                i for i, t in enumerate(seg_tokens)
                if t.rsplit("/", 1)[-1] in known | _MOCK_SCRIPTS
            ]
            if not hits:
                ids.update(_generic_scan(seg_tokens))
                continue
            for i in hits:
                if seg_tokens[i].rsplit("/", 1)[-1] in _MOCK_SCRIPTS:
                    continue
                sids, sopaque = _selector_ids(seg_tokens, i)
                ids.update(sids)
                opaque.extend(sopaque)
    return ids, opaque


def _collect_ids(args: argparse.Namespace) -> tuple[set[str], list[str]]:
    ids: set[str] = set()
    for t in args.ids:
        ids.update(p for p in _pieces(t) if p)
    for f in args.tasks_file or []:
        ids.update(read_ids(Path(f)))
    opaque: list[str] = []
    if args.cmd:
        cids, copaque = resolve_cmd(args.cmd)
        ids.update(cids)
        opaque.extend(copaque)
    return ids, opaque


def _sort_ids(ids) -> list[str]:
    return sorted(
        ids, key=lambda s: (0, int(s)) if str(s).isdigit() else (1, str(s))
    )


def main() -> int:
    ap = argparse.ArgumentParser(
        prog="check_split.py",
        description="test-20 exposure gate — see module docstring",
    )
    sub = ap.add_subparsers(dest="action", required=True)
    for name, helptext in (
        ("gate", "refuse if any test-20 id lacks a ledger line"),
        ("record", "append an exposure line to the ledger"),
    ):
        p = sub.add_parser(name, help=helptext)
        p.add_argument("ids", nargs="*", help="task ids")
        p.add_argument(
            "--tasks-file",
            action="append",
            help="file of task ids, one per line (repeatable)",
        )
        p.add_argument(
            "--cmd",
            help="bench/tau2 invocation to scan for task ids",
        )
        if name == "record":
            p.add_argument("--purpose", required=True)
            p.add_argument("--who", required=True, dest="who_looked")
            p.add_argument(
                "--binary",
                help="file to sha256 into binary_hash (e.g. the gate binary)",
            )
    args = ap.parse_args()

    ids, opaque = _collect_ids(args)

    if args.action == "gate":
        if opaque:
            for reason in opaque:
                print(f"SPLIT GATE REFUSE — opaque selection: {reason}")
            return 1
        bad = uncovered(ids)
        if bad:
            print(
                "SPLIT GATE REFUSE — test-20 ids with no ledger line: "
                + ", ".join(bad)
            )
            print(
                "  record the exposure first: python3 bench/check_split.py "
                f"record --purpose \"<why>\" --who \"<who>\" {' '.join(bad)}"
            )
            return 1
        test_hit = sorted(ids & test_ids())
        if test_hit:
            print(
                "SPLIT GATE PASS — test-20 ids covered by ledger: "
                + ", ".join(_sort_ids(test_hit))
            )
        else:
            print(f"SPLIT GATE PASS — no test-20 ids in selection ({len(ids)} ids)")
        return 0

    # record
    if not ids:
        sys.exit("record needs at least one task id (--tasks/--tasks-file/--cmd)")
    binary_hash = None
    if args.binary:
        b = Path(args.binary)
        if not b.exists():
            sys.exit(f"--binary not found: {b}")
        binary_hash = hashlib.sha256(b.read_bytes()).hexdigest()
    entry = {
        "date": date.today().isoformat(),
        "task_ids": _sort_ids(ids),
        "binary_hash": binary_hash,
        "purpose": args.purpose,
        "who_looked": args.who_looked,
    }
    ledger = _ledger_path()
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    print(f"ledger += {json.dumps(entry)}")
    outside = sorted(p for p in ids if p not in split_ids("train-30.txt") | test_ids())
    if outside:
        print(f"note: ids outside the frozen 50 recorded verbatim: {', '.join(outside)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
