#!/usr/bin/env python3
"""Spend gate — live model runs are impossible by default.

Any bench path that would call a paid/hosted model must call
`require(...)` before the first model call. Approval is per-invocation:
`KOPIUM_BENCH_SPEND_OK="what / estimate"` in the environment of the run
itself — no file, nothing persists, the approval string is printed into
the run log so every spend carries its own receipt.

Rules, in order:
  - model contains "openrouter"      -> unconditional REFUSE. Lars's
    ruling 2026-11-12: bench never touches OpenRouter until he rules the
    correctness signals extremely strong. No env var overrides this.
  - every model looks local          -> PASS, $0 (informational only).
  - anything else                    -> REFUSE unless KOPIUM_BENCH_SPEND_OK
    is set; its content is the approval record.

Zero-spend paths (summarize-only, cached replays, corpus mining,
gate_probe, callstep_parity) never call this and never gate.

Burned 2026-11-12: two measurement commissions spent $1.62 through
proxied agents after a no-OpenRouter-calls instruction — the rule was
prose, the spend was real. This file is the wall.
"""

import os
import re
import sys

APPROVAL_ENV = "KOPIUM_BENCH_SPEND_OK"
LOCAL_HINTS = ("ollama", "lmstudio", "localhost", "127.0.0.1",
               "local/", "@local", "/v1/local")


def _models(model: str) -> list[str]:
    return [t for t in re.split(r"[\s,|]+", model) if t]


def _is_local(m: str) -> bool:
    return any(h in m.lower() for h in LOCAL_HINTS)


def require(what: str, model: str = "") -> None:
    models = _models(model)
    if any("openrouter" in m.lower() for m in models):
        print(f"SPEND GATE REFUSE — {what}: OpenRouter is banned for bench "
              "runs until Lars rules the correctness signals extremely "
              "strong (2026-11-12). No approval overrides this.",
              file=sys.stderr)
        sys.exit(1)
    if models and all(_is_local(m) for m in models):
        print(f"SPEND GATE PASS — {what}: local model(s) {model} — $0")
        return
    approval = os.environ.get(APPROVAL_ENV, "").strip()
    if not approval:
        print(f"SPEND GATE REFUSE — {what}: hosted/non-local model "
              f"({model or 'unset'}). Re-run with {APPROVAL_ENV}=\"what "
              "/estimate\" only on Lars's explicit approval.",
              file=sys.stderr)
        sys.exit(1)
    print(f"SPEND GATE PASS — {what}: approval '{approval[:200]}' "
          f"for model {model}")


def main() -> None:
    approval = os.environ.get(APPROVAL_ENV, "").strip()
    print(f"{APPROVAL_ENV}={'SET: ' + approval[:120] if approval else 'unset'}")
    print("OpenRouter: unconditionally refused for bench runs (2026-11-12 ruling)")


if __name__ == "__main__":
    main()
