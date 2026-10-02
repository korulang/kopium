#!/usr/bin/env python3
"""
Prompt-integrity guard for the measured arm — no model calls, no spend.

The prompt now lives inside the Koru agent (bench/tau-agent.k +
bench/tau_wire.kz): derived grammar, the generated tool-contract doc, and
the domain policy spliced verbatim — every request body is receipted to
KOPIUM_RECEIPT_DIR. The Python side is a line marshal and must stay one.

This guard fails loudly (exit 1) if the marshal regrows a channel: model
calls, prompt assembly, verb/tool name tables, regex wire-parsing, retries,
or fallback prose. The contamination channels documented in
CONTAMINATION-2026-09-27.md can only reappear HERE — the Koru side's
request body is one splice of three verifiable sources.

Run:  python3 bench/prompt_guard.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
SHIM = HERE / "kopium_agent.py"


def fail(msg: str) -> None:
    print(f"GUARD FAIL: {msg}")
    sys.exit(1)


def check_shim_stays_a_marshal() -> None:
    src = SHIM.read_text()
    # Strip comments and docstrings: the check is about executable surface,
    # not about prose that documents what is absent.
    code_lines = []
    in_doc = False
    for line in src.splitlines():
        s = line.strip()
        if s.startswith('"""'):
            in_doc = not in_doc or s.count('"""') == 2
            if s.count('"""') == 2:
                in_doc = False
            continue
        if in_doc or s.startswith("#"):
            continue
        code_lines.append(line)
    code = "\n".join(code_lines)

    if re.search(r"\bimport re\b", code):
        fail("shim imports re — wire parsing does not belong in Python")
    if re.search(r"litellm|llm_utils|\bgenerate\(", code):
        fail("shim calls a model — the model call lives in tau-agent.k")
    for token in ("_system_prompt", "extra_rules", "koru_to_tau",
                  "DomainConfig", "_CONFIGS"):
        if token in code:
            fail(f"shim references {token} — a named coaching/mapping channel")
    if re.search(r"except[^:]*:\s*(return|pass|continue)\b", code):
        fail("shim swallows an exception — loud failure or nothing")
    # No authored strings may cross the wire inbound: every _send payload is
    # a transport shape whose only literals are the kind enum — content is
    # always passthrough (message.content, domain_policy), never a literal.
    for m in re.finditer(r"_send\(\{(.*?)\}\)", code, re.DOTALL):
        for lit in re.findall(r'"([^"]*)"', m.group(1)):
            if lit not in ("", "kind", "init", "user", "result", "id",
                           "content", "text", "policy"):
                fail(f"shim _send carries a literal {lit!r} — payloads are "
                     "transport enums and passthrough fields only")
    print("  [ok] shim is a marshal: no model call, no names, no regex, no fallback")


def check_agent_binary_source() -> None:
    for f in ("tau-agent.k", "tau_wire.kz"):
        if not (HERE / f).exists():
            fail(f"{f} missing — the agent is Koru; there is no arm without it")
    print("  [ok] tau-agent.k + tau_wire.kz present")


def main() -> None:
    check_agent_binary_source()
    check_shim_stays_a_marshal()
    print("GUARD PASS")


if __name__ == "__main__":
    main()
