#!/usr/bin/env python3
"""RunLogger — JSONL run log, the portal's only data source.

One event per line in logs/runs/<run_id>.jsonl. The `gen` event carries
the FULL assembled context (system + transcript) exactly as sent to the
model — consecutive-context diffs are the transparency point. Everything
else (gate events, observations, verdicts) is the timeline around it.

Event types:
  run_start  — config: task, arm, steps, draft, model, seed, gate
  system     — the assembled system prompt, once
  gen        — n, temperature, messages (full context), response fields
  wire       — wire program text sent to the gate
  gate_call  — {"kind":"call"} event: name, arguments, id
  gate_say   — {"kind":"say"} event: text
  gate_status— turn verdict: OK/HALT/REJECT/ERROR/STEPS/DEFINED + detail
  observe    — transcript observation (role, content) fed back to model
  flow       — queued flow dispatched to the gate
  reject     — generation rejected by the gate, attempt number
  run_end    — reward, call counts, wall time
"""

from __future__ import annotations

import json
import os
import time
from pathlib import Path

RUNS_DIR = Path(__file__).resolve().parent.parent / "logs" / "runs"


class RunLogger:
    def __init__(self, run_id: str, out_dir: Path = RUNS_DIR):
        out_dir.mkdir(parents=True, exist_ok=True)
        self.run_id = run_id
        self.path = out_dir / f"{run_id}.jsonl"
        self._f = open(self.path, "w")
        self.t0 = time.time()

    def event(self, type_: str, **fields) -> None:
        rec = {"type": type_, "ts": round(time.time() - self.t0, 3), **fields}
        self._f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        self._f.flush()

    def close(self) -> None:
        self._f.close()


def slug(*parts: object) -> str:
    """Filesystem-safe run id: slug parts joined, timestamped."""
    clean = "-".join(
        "".join(c if c.isalnum() or c in "-_" else "-" for c in str(p).lower())
        for p in parts
    )
    return f"{clean}-{time.strftime('%Y%m%d-%H%M%S')}"
