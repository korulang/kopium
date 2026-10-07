#!/usr/bin/env python3
"""Parametricity on the scoreboard: the surface derives, it is not possession-shaped.

Charter: "a second domain vocabulary — parametricity is proven by two, not
one." `headless/probe_calc.k` drives the `calc` scope — a vocabulary with no
handles, no open/close, nothing to hold — through the same std/bridge:run the
notes session uses, and asserts the whole derivation: the vocabulary renders
calc's verbs, the grammar teaches the shared wire rules (and no handle
vocabulary this domain does not have), foreign verbs die at event-denied,
world state crosses items while bindings cannot, and define-growth is
per-scope.

One FORBIDDEN needle is structural, not cosmetic: the rendered grammar must
not teach `| ?` — a retired arm spelling. That line lives in koru_std's
wireval and only clears once the residual-arms wording reaches the installed
tree, so this case is red until it lands — which is the signal.

  python3 bench/probe_calc.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BENCH = Path(__file__).parent
HEADLESS = BENCH.parent / "headless"
SRC = HEADLESS / "probe_calc.k"
BIN = HEADLESS / "a.out"

NEEDLES = [
    # 1. the derived vocabulary is calc's — the register block rendered, not
    # a possession domain's verbs
    ("vocab lists div with branches", "div(a: string, b: string) | quotient string | by-zero string"),
    ("vocab lists recall", "recall(name: string) | ok string | missing string"),
    # 3-5. branches bind payloads and handled refusals fire — zero handles held
    ("add binds sum", "[add-ok] result handles=0"),
    ("by-zero arm fires with payload", "[div-zero] result handles=0"),
    ("bad-input is a handled refusal", "[add-bad] result handles=0"),
    # 6. an arm body naming an unbound name is validation-error, not dispatch
    ("unbound name refused", "validation-error unbound 't' on 'say'"),
    # 7. the wall holds against BOTH foreign vocabularies — notes and ledger
    ("notes verb denied", "[denied-notes] event-denied open"),
    ("ledger verb denied", "[denied-ledger] event-denied open-acct"),
    # 8. invented fields refuse through the derived input grammar
    ("invented field refused", "validation-error unknown field 'bogus' on 'add'"),
    # 9. world state crosses items even though bindings cannot
    ("remember/recall across items", "[memory] partial 2/2"),
    # 10. define-growth works on the second vocabulary
    ("define installs on calc", "[define] defined shout"),
    ("defined verb dispatches", "[call] result handles=0"),
]

# The rendered grammar must not teach retired spellings as arm shapes.
FORBIDDEN = [
    ("grammar teaches no `| ?` arm", "| ?` outcome"),
]


def main() -> int:
    if not SRC.exists():
        print(f"FAIL: missing {SRC}")
        return 1
    r = subprocess.run(["koruc", SRC.name], cwd=HEADLESS, capture_output=True, text=True)
    if r.returncode != 0:
        print("FAIL: koruc probe_calc.k")
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
    ok = True
    for label, needle in NEEDLES:
        if needle in out:
            print(f"PASS  {label}")
        else:
            print(f"FAIL  {label} — missing: {needle!r}")
            ok = False
    for label, needle in FORBIDDEN:
        if needle in out:
            print(f"FAIL  {label} — found: {needle!r}")
            ok = False
        else:
            print(f"PASS  {label}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
