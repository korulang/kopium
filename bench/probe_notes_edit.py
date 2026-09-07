#!/usr/bin/env python3
"""Zero-token proof: the notes bridge can rewrite the disk through `edit`.

The forcing (vulcan-forcing 2026-09-07): go-stack-pop-bug needs file-edit —
the bridge can open a file's eyes (read) but not its hands. This probe drives
a scripted `edit` through `std/bridge:run` in `headless/probe_notes_edit.k`,
the same dispatch `session.k` turns and `live.k` drive call — and asserts the
whole loop: a single-match rewrite lands on disk, a missing file reports
not-found without creating, a zero-match reports mismatch, a multi-match
refuses ambiguous, all three refusals write nothing, the derived vocabulary
lists `edit`, and an undeclared near-synonym is still denied (smallest wall
kept).

  python3 bench/probe_notes_edit.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_notes_edit.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # 2. the vulcan patch step: one needle, one match, disk rewritten
    ("single-match runs", "[edit] ok: 'probe_edit_fixture.txt'"),
    ("result arm, nothing minted", "edit ran — bridge holds 0 resource(s), nothing minted"),
    # 3. after bytes show the replacement
    ("after bytes on transcript", "the slow green frog"),
    # 4. absence reports, never creates
    ("missing reports not-found", "[edit] not-found: 'no-such-file.txt'"),
    ("miss still runs the verb", "missing ran — bridge holds 0 resource(s), nothing written"),
    # 5. zero matches is mismatch
    ("zero matches mismatch", "[edit] mismatch: needle not found in 'probe_edit_fixture.txt'"),
    # 6. multi-match refuses
    ("multi-match ambiguous", "[edit] ambiguous: needle matches more than once in 'probe_edit_fixture.txt'"),
    # 7. refusals wrote nothing: separate read, distinct marker
    ("refusals wrote nothing", "refusals confirmed — fixture still reads with the single replacement"),
    # 8. the derived vocabulary includes edit
    ("vocabulary lists edit", "edit(path: string, old_text: string, new_text: string)"),
    # 9. the wall did not move
    ("contrast denies replace", "DENIED replace"),
    # 10. the session outlives every refusal
    ("bridge survives", "still here after every refusal"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_notes_edit.k")
        print(r.stdout + r.stderr)
        return 1
    if not BIN.exists():
        print("FAIL: koruc produced no a.out")
        return 1
    r = subprocess.run([str(BIN)], cwd=HEADLESS, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        print("FAIL: probe binary exited nonzero")
        print(out)
        return 1
    failed = 0
    for name, needle in NEEDLES:
        if needle in out:
            print(f"PASS  {name}")
        else:
            print(f"FAIL  {name} — missing {needle!r}")
            failed += 1
    if "WRONG" in out:
        print("FAIL  probe printed a WRONG arm")
        failed += 1
    if failed:
        return 1
    print("PASS: edit rewrites disk files through the bridge, canned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
