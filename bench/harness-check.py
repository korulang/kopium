#!/usr/bin/env python3
"""The harness wall — one exit code for the decisions we already made.

Each case is a named join: something true of the long-running bridge that
must stay true of the path KopiumAgent uses (or a 440_ pin the bench
witnesses). `python3 bench/harness-check.py` rebuilds the binaries from
source, runs every case, and the process exit code IS the verdict.

  python3 bench/harness-check.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent

# decision, pin-or-claim, probe
CASES: list[tuple[str, str, str]] = [
    ("persist", "one Bridge, many lines", "probe_persist.py"),
    ("define", "session table survives the line", "probe_define.py"),
    ("live-define", "define completes on the live drive path, canned", "probe_live_define.py"),
    ("multiline", "a multi-item turn sequences and reports per step", "probe_multiline.py"),
    ("define-in-turn", "define and use a verb in the same turn", "probe_define_use.py"),
    ("consumers", "every bridge:run caller compiles (exhaustive arms)", "probe_consumers.py"),
    ("mock-on-session", "mock register on session.k shape", "probe_session_mock.py"),
    ("live-vocab", "vocabulary is this Bridge, including inventions", "probe_vocab_live.py"),
    ("440_012", "redefine replaces the body", "probe_440_012.py"),
    ("440_017", "grammar is wire rules + inventions", "probe_440_017.py"),
    ("440_009", "run discriminates deny / define / dispatch", "probe_440_009.py"),
    ("frontier-001", "oracle-first redefine round-trip (git-leak-recovery)", "frontier/probe_frontier_001.py"),
    ("frontier-002", "fresh restore: foreign inventions absent, forks diverge", "frontier/probe_frontier_002.py"),
    ("frontier-003", "inventions accumulate: second define never evicts first", "frontier/probe_frontier_003.py"),
    ("frontier-004", "re-dispatch is deterministic: same call, same verdict", "frontier/probe_frontier_004.py"),
    ("frontier-005", "wire gate: prose/trailing/chained/truncated refuse, session survives", "frontier/probe_frontier_005.py"),
    ("frontier-006", "defined inventions forward caller arguments", "frontier/probe_frontier_006.py"),
    ("frontier-007", "unrelated define never perturbs a live neighbor's verdict", "frontier/probe_frontier_007.py"),
    ("notes-read", "read opens disk files to the bridge, canned", "probe_notes_read.py"),
    ("notes-edit", "edit rewrites disk files through the bridge, canned", "probe_notes_edit.py"),
    ("notes-unhandled", "named-branch read hands back under the lenient bridge", "probe_unhandled_read.py"),
    ("affordances", "callable surface is possession-shaped (HATEOAS rooms)", "probe_affordances.py"),
    ("opaque-handles", "THE RULING: handles are opaque, binding-only (Lars 09-07/08)", "probe_opaque_handles.py"),
]

BUILDS = (
    ("mock-gate.k", "mock-gate-binary"),
    ("session-mock.k", "session-mock-binary"),
)


def rebuild() -> None:
    for src, dest in BUILDS:
        print(f"build {src} → {dest}", flush=True)
        r = subprocess.run(["koruc", src], cwd=BENCH)
        if r.returncode != 0:
            raise SystemExit(f"FAIL: koruc {src}")
        built = BENCH / "a.out"
        if not built.exists():
            raise SystemExit(f"FAIL: koruc {src} produced no a.out")
        built.replace(BENCH / dest)


def main() -> int:
    rebuild()
    print()
    failed: list[str] = []
    for name, claim, probe in CASES:
        r = subprocess.run(
            [sys.executable, str(BENCH / probe)],
            cwd=BENCH,
            capture_output=True,
            text=True,
        )
        status = "PASS" if r.returncode == 0 else "FAIL"
        print(f"{status}  {name:16}  {claim}")
        if r.returncode != 0:
            failed.append(name)
            out = (r.stdout or "") + (r.stderr or "")
            for line in out.splitlines():
                if line.startswith("FAIL") or line.startswith("PASS"):
                    print(f"      {line}")
    print()
    n = len(CASES)
    ok = n - len(failed)
    print(f"harness-check  {ok}/{n}")
    if failed:
        print("red: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
