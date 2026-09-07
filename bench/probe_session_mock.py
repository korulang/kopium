#!/usr/bin/env python3
"""Zero-token proof: mock register on the session.k machine.

  python3 bench/probe_session_mock.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BIN = Path(__file__).parent / "session-mock-binary"


def main() -> int:
    if not BIN.exists():
        print(f"FAIL: missing {BIN} — koruc session-mock.k && cp a.out session-mock-binary")
        return 1
    proc = subprocess.run([str(BIN)], capture_output=True, text=True, timeout=15)
    out = proc.stdout
    print(out, end="" if out.endswith("\n") else "\n")
    if proc.returncode != 0:
        print(f"FAIL: session-mock-binary exited {proc.returncode}")
        if proc.stderr:
            print(proc.stderr)
        return 1
    if "defined greet" not in out:
        print("FAIL: define did not install greet on the session Bridge")
        return 1
    if "DENIED" not in out or "sync" not in out:
        print("FAIL: unknown verb was not denied at the register wall")
        return 1
    marker = "--- vocabulary (register + inventions)"
    if marker not in out:
        print("FAIL: no vocabulary render")
        return 1
    vocab = out.split(marker, 1)[1]
    if "say(" not in vocab:
        print("FAIL: vocabulary missing compiled say — not the mock register")
        return 1
    if "greet(" not in vocab:
        print("FAIL: vocabulary missing invented greet — not the live-session shape")
        return 1
    print("PASS: mock register on session.k shape, vocabulary includes inventions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
