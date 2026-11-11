"""model_guard.py — the bench's model-choice wall. One check, every entry point.

Twice now an Anthropic arm has burned ~$20 in minutes through OpenRouter
(2026-08-15 haiku, 2026-10-11 sonnet — the second time it emptied the account
to $0.38). The rule lived in SESSION_2026-08-16.md, a document nothing reads
before running. Now it lives in code: every bench entry point that lets a
caller pick a model runs the slug through guard_llm() first.

OpenRouter is banned outright for bench runs (Lars ruling 2026-11-12):
no approval mechanism overrides it until he rules the correctness signals
extremely strong — enforced here so every entry point inherits it.

Override: BENCH_ALLOW_ANTHROPIC=1 — an explicit per-invocation act, never an
env that happens to be set.
"""

import os
import sys

ALLOW_ENV = "BENCH_ALLOW_ANTHROPIC"


def guard_llm(llm: str) -> str:
    """Return the slug unchanged if allowed, else exit with teaching."""
    lowered = llm.lower()
    if "openrouter" in lowered:
        sys.exit(
            f"model {llm} refused: OpenRouter is banned for bench runs "
            f"(Lars ruling 2026-11-12 — no rerun of the reference path "
            f"until correctness signals are extremely strong)."
        )
    if ("anthropic" in lowered or "claude" in lowered) and not os.environ.get(
        ALLOW_ENV
    ):
        sys.exit(
            f"model {llm} refused: Anthropic models are banned for bench runs "
            f"(burned ~$20/run twice: 2026-08-15, 2026-10-11). Use the deepseek "
            f"default, or set {ALLOW_ENV}=1 for one deliberate run."
        )
    return llm
