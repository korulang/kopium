#!/usr/bin/env python3
"""Marshal tau2's airline openai_schema to JSON — transport only.

Koru's generator (gen_airline.kz) cannot read Python objects; this shim
serializes what tau2 already exposes to stock agents — each @is_tool
method's openai_schema["function"] plus its write/read classification —
into airline_schema.json. Every semantic decision (name mapping, field
types, costs, doc wording, ordering beyond the alphabetical tool list)
lives in the .kz, never here.

Run: ../tau2-bench/.venv/bin/python dump_airline_schema.py
Output: airline_schema.json — GENERATED, do not hand-edit.
"""

import inspect
import json
import sys
from pathlib import Path

TAU2 = Path(__file__).resolve().parent.parent.parent / "tau2-bench"
sys.path.insert(0, str(TAU2 / "src"))

from tau2.domains.airline.tools import AirlineTools  # noqa: E402
from tau2.environment.toolkit import ToolType  # noqa: E402
from tau2.environment.tool import Tool  # noqa: E402

tools = []
for name, fn in inspect.getmembers(AirlineTools, inspect.isfunction):
    if name.startswith("_") or not getattr(fn, "__tool__", False):
        continue
    tools.append(
        {
            "name": name,
            "write": getattr(fn, "__tool_type__", ToolType.GENERIC)
            == ToolType.WRITE,
            "function": Tool(func=fn).openai_schema["function"],
        }
    )

if not tools:
    raise SystemExit(
        "dump_airline_schema: no @is_tool methods found — is the decorator "
        "attribute '__tool__' still the marker? Check tau2 toolkit.py"
    )

out = Path(__file__).with_name("airline_schema.json")
out.write_text(json.dumps({"tools": tools}, indent=1) + "\n")
print(f"dumped {len(tools)} tool schemas -> {out.name}")
