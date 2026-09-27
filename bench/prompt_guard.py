#!/usr/bin/env python3
"""
Prompt-integrity guard for the measured arm — no model calls, no spend.

Fails loudly (exit 1) if any of the contamination channels documented in
CONTAMINATION-2026-09-27.md can reappear:

  1. `extra_rules` must not exist on DomainConfig — as a dataclass field,
     on any config instance, or as an attribute at runtime. The channel is
     deleted, not emptied: a measured arm must be structurally incapable of
     consuming hand-written behavioral prose.

  2. The rendered system prompt must decompose into EXACTLY four sources,
     each verifiable against its origin:
       - intro paragraph: wire mechanics only (no domain verbs)
       - `## Koru` section: the gate's own `bridge:grammar` render
       - the generated tool-contract doc: byte-identical to
         `<domain>_vocab_doc.md` (emitted by gen_*_tors.py from tau2's
         openai_schema — never hand-edited)
       - `## Growth` section: wire-syntax documentation; must use only the
         synthetic `greet` example, never a real domain verb
       - `## Domain policy`: byte-identical to env.get_policy()
     Nothing else may appear — every `##`/`#` header must be in the
     allowed set, and no domain verb may be named in prose sections
     (a `cancel-reservation` worked example is coaching even when framed
     neutrally — that exact failure shipped).

Run:  python3 bench/prompt_guard.py            # checks all domains
      python3 bench/prompt_guard.py airline    # one domain
"""

from __future__ import annotations

import dataclasses
import hashlib
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

from kopium_agent import DomainConfig, KopiumAgent, _CONFIGS  # noqa: E402

ALLOWED_H2 = {"## Koru", "## Growth", "## Domain policy"}
ALLOWED_H1 = {"# Tool contract"}


def fail(msg: str) -> None:
    print(f"GUARD FAIL: {msg}")
    sys.exit(1)


def check_no_extra_rules() -> None:
    field_names = {f.name for f in dataclasses.fields(DomainConfig)}
    if "extra_rules" in field_names:
        fail("DomainConfig has an extra_rules field — the coaching channel is back")
    for name, cfg in _CONFIGS.items():
        if hasattr(cfg, "extra_rules"):
            fail(f"{name} config instance carries extra_rules")
    # A re-added prompt injection site would name the field. Comments that
    # document its absence are fine; an f-string consuming it is not.
    src = (HERE / "kopium_agent.py").read_text()
    for m in re.finditer(r"extra_rules", src):
        line = src[: m.start()].count("\n") + 1
        text = src.splitlines()[line - 1].strip()
        if not text.startswith("#") and 'extra_rules' in text:
            fail(f"kopium_agent.py:{line} references extra_rules in code: {text}")
    print("  [ok] extra_rules absent — field deleted, no code reference")


def check_prompt_shape(domain: str) -> None:
    from tau2.runner import build_environment

    env = build_environment(domain)
    agent = KopiumAgent(
        tools=env.get_tools(), domain_policy=env.get_policy(),
        domain=domain, gate_binary=HERE / f"{domain}-gate-binary",
    )
    prompt = agent._system_prompt()
    cfg = agent.cfg
    agent.close_gate()

    # --- the policy block is verbatim (checked first so its own internal
    #     headers are exempt from the authored-surface scan below) ---------
    policy_mark = "\n## Domain policy\n"
    if policy_mark not in prompt:
        fail(f"{domain}: no ## Domain policy section")
    authored, policy_part = prompt.split(policy_mark, 1)
    if policy_part != env.get_policy():
        fail(f"{domain}: domain policy is not verbatim env.get_policy()")
    print("  [ok] domain policy byte-identical to tau2 source")

    # --- the vocab doc is verbatim generated output ------------------------
    doc_path = HERE / f"{domain}_vocab_doc.md"
    if doc_path.exists():
        doc = doc_path.read_text().strip()
        if doc not in authored:
            fail(f"{domain}: vocab doc modified in transit — not verbatim")
        authored = authored.replace(doc, "", 1)
        print("  [ok] tool-contract doc spliced verbatim from generated file")

    # --- every header on the authored surface is in the allowed set --------
    # (verbatim blocks removed above; the grammar render lives under its
    # own ## Koru header)
    for line in authored.splitlines():
        if line.startswith("## "):
            h2 = line.split("—")[0].split("(")[0].strip()
            if h2 not in ALLOWED_H2 - {"## Domain policy"}:
                fail(f"{domain}: disallowed prompt section {line!r}")
        elif line.startswith("# "):
            fail(f"{domain}: disallowed prompt header {line!r}")
    print("  [ok] authored surface carries only intro + ## Koru + ## Growth")

    # --- prose sections must not name a domain verb -------------------------
    # The doc and grammar legitimately list verbs; the authored sections
    # (intro paragraph, ## Growth) may not. Naming `cancel-reservation` in a
    # worked example is exactly the contamination class this guards.
    sections = re.split(r"\n(?=##? )", authored)
    domain_verbs = set(cfg.koru_to_tau) | set(cfg.koru_to_tau.values())
    for sec in sections:
        head = sec.splitlines()[0]
        if head.startswith("## Koru"):
            continue
        for verb in domain_verbs:
            if re.search(rf"\b{re.escape(verb)}\b", sec):
                fail(
                    f"{domain}: domain verb {verb!r} named in authored "
                    f"prompt section ({head[:60]!r}) — coaching surface"
                )
    print("  [ok] no domain verb in authored prose (intro/growth)")

    # --- report -------------------------------------------------------------
    sha = hashlib.sha256(prompt.encode()).hexdigest()[:16]
    print(f"  {domain}: prompt sha256 {sha} — {len(prompt)} chars, sections verified")


def main() -> None:
    domains = sys.argv[1:] or list(_CONFIGS)
    check_no_extra_rules()
    for d in domains:
        if d not in _CONFIGS:
            fail(f"unknown domain {d!r}")
        print(f"guard: {d}")
        check_prompt_shape(d)
    print("GUARD PASS")


if __name__ == "__main__":
    main()
