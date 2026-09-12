#!/usr/bin/env python3
"""Zero-token proof: every `std/bridge:run` caller still compiles.

The bridge's branch set grows (e.g. `?partial`, `unhandled-branch`), and each
caller owns an exhaustive switch over it. A sweep that adds an arm by hand can
break a caller the wall never compiles — which is exactly what happened to
`headed.k` in `5c683fc` (its `announce(ma.text)` continuation was stolen by the
new arm, leaving `ma` out of scope). This probe compiles every agent-path
caller, so a broken consumer is a red case, not a surprise later.

  python3 bench/probe_consumers.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
ROOT = BENCH.parent

# Every program on the agent path that switches over `std/bridge:run`,
# as (directory, source) — the head moved to tui/ in cc9911c.
CONSUMERS = [
    ("headless", "session.k"),
    ("headless", "live.k"),
    ("tui", "headed.k"),
]


def main() -> int:
    failed = 0
    for dirname, name in CONSUMERS:
        src = ROOT / dirname / name
        if not src.exists():
            print(f"FAIL  {dirname}/{name} — missing")
            failed += 1
            continue
        r = subprocess.run(["koruc", name], cwd=ROOT / dirname, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"FAIL  {name} — does not compile")
            for line in ((r.stdout or "") + (r.stderr or "")).splitlines():
                if "error" in line.lower():
                    print(f"      {line}")
            failed += 1
        else:
            print(f"PASS  {name}")
    if failed:
        return 1
    print("PASS: every bridge:run caller compiles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
