#!/usr/bin/env python3
"""Spend gate — live model runs are impossible by default.

Any bench path that would spend OpenRouter tokens must call
`require(...)` before the first model call. It refuses loudly unless
`bench/SPEND-OK` exists — a file only Lars creates when he approves a
specific spend. The file's content IS the approval record (who, what,
estimate); it is printed into the run log so approvals stay auditable.

Zero-spend paths (summarize-only, cached replays, corpus mining,
gate_probe, callstep_parity) never call this and never gate.

Burned 2026-11-12: two measurement commissions spent $1.62 through
proxied agents after a no-OpenRouter-calls instruction — the rule was
prose, the spend was real. This file is the wall.
"""

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
APPROVAL = HERE / "SPEND-OK"


def require(what: str) -> None:
    if not APPROVAL.exists():
        print(f"SPEND GATE REFUSE — {what}: no bench/SPEND-OK approval file. "
              "Live model runs need Lars's explicit per-commission approval; "
              "he creates bench/SPEND-OK containing who/what/estimate.",
              file=sys.stderr)
        sys.exit(1)
    body = APPROVAL.read_text().strip() or "(empty approval file)"
    print(f"SPEND GATE PASS — {what}: approval on file -> {body.splitlines()[0][:200]}")


def main() -> None:
    if APPROVAL.exists():
        print(f"SPEND GATE OPEN — {APPROVAL} exists:")
        print(APPROVAL.read_text().strip())
    else:
        print("SPEND GATE CLOSED — bench/SPEND-OK absent; live runs refuse")


if __name__ == "__main__":
    main()
