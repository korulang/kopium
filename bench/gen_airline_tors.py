#!/usr/bin/env python3
"""Generate airline_tools.kz from tau2's real schemas — parity by construction.

The hand-transcribed mirror was the drift risk: every time tau2's tools.py
moved, the gate's declared surface silently desynchronized from what the
stock arm's prompt advertised. This generator walks each @is_tool method's
openai_schema (the SAME schema stock agents see) and emits the tor block:
scalar params become typed Koru fields (integer -> i64), arrays/objects
become JSON-in-string params (the wire has no composite literals), enums
stay string.

Run: ../tau2-bench/.venv/bin/python gen_airline_tors.py
Output: airline_tools.kz — GENERATED, do not hand-edit.

`say` is NOT a tau2 tool — it is the Koru voice channel, emitted here as a
fixed preamble so the register block stays one file.
"""

import json
import sys
from pathlib import Path

TAU2 = Path(__file__).resolve().parent.parent.parent / "tau2-bench"
sys.path.insert(0, str(TAU2 / "src"))

from tau2.domains.airline.tools import AirlineTools  # noqa: E402
from tau2.environment.toolkit import ToolType, is_tool  # noqa: E402
import inspect  # noqa: E402
from tau2.environment.tool import Tool  # noqa: E402

# ---------------------------------------------------------------------------
# scalar schema -> (koru type, zig format verb, quoted?)
# ---------------------------------------------------------------------------

def _koru_type(prop: dict) -> str:
    """JSON-schema type -> Koru wire type. Composite types carry JSON inside
    a string param — the proc splices them raw so real lists reach tau2."""
    t = prop.get("type")
    if t is None or t in ("array", "object") or "anyOf" in prop or "$ref" in prop:
        return "json"  # JSON-in-string marker — raw splice, no quotes
    return {
        "string": "string",
        "integer": "i64",
        "number": "f64",
        "boolean": "bool",
    }.get(t) or _die(f"unmapped schema type {prop!r}")


def _die(msg: str):
    raise SystemExit(f"gen_airline_tors: {msg}")


def _emit_tor(name: str, tool: Tool) -> str:
    """One tor + proc. The proc echoes its parsed inputs as JSON — the gate's
    marshalling boundary; tau2 executes the real tool south of this."""
    schema = tool.openai_schema["function"]["parameters"]
    props = {k: v for k, v in schema.get("properties", {}).items()
             if k != "self"}
    required = set(schema.get("required", []))
    optional = [p for p in props if p not in required]
    if optional:
        # The wire has no optional params yet — declaring one required would
        # make the gate STRICTER than the stock arm's schema. Fail loud.
        _die(f"{name} has optional params {optional} — the wire cannot "
             "declare them; extend the grammar before regenerating")

    koru_name = name.replace("_", "-")
    fields = [(p, _koru_type(props[p])) for p in props]
    params = ", ".join(f"{n}: {('string' if k == 'json' else k)}"
                       for n, k in fields)

    buf = 4096 if any(k == "json" for _, k in fields) else 1024
    buf = max(buf, 2048 if len(fields) > 4 else buf)

    json_pairs = []
    zig_args = []
    esc_lines = []
    esc_n = 0
    for n, k in fields:
        if k == "json":
            json_pairs.append(f'\\"{n}\\": {{s}}')          # raw splice
            zig_args.append(n)
        elif k == "string":
            # Quoted params go through __jsonEsc — a raw splice writes a
            # runtime newline/quote into the JSON unescaped and the
            # marshal's inner parse fails (measured 2026-09-27: say()
            # with \n\n in text marshalled to an empty user message).
            json_pairs.append(f'\\"{n}\\": \\"{{s}}\\"')
            esc_lines.append(
                f"    var __e{esc_n}: [{buf}]u8 = undefined;\n"
                f"    const {n}_v = __jsonEsc({n}, &__e{esc_n});"
            )
            zig_args.append(f"{n}_v")
            esc_n += 1
        else:
            json_pairs.append(f'\\"{n}\\": {{{"d"}}}')      # numeric raw
            zig_args.append(n)
    fmt = "{{" + ", ".join(json_pairs) + "}}"
    arglist = ", ".join(zig_args)

    if not fields:
        proc_body = '    return "{}";'
    else:
        esc_block = ("\n".join(esc_lines) + "\n") if esc_lines else ""
        proc_body = (
            "    const __S = struct { threadlocal var buf: "
            f"[{buf}]u8 = undefined; }};\n"
            f"{esc_block}"
            f"    const s = std.fmt.bufPrint(&__S.buf,\n"
            f'        "{fmt}",\n'
            f"        .{{ {arglist} }}) catch \"{{}}\";\n"
            "    return s;"
        )
    return (
        f"~pub tor {koru_name} {{ {params} }} -> string\n\n"
        f"~proc {koru_name}|zig {{\n{proc_body}\n}}\n"
        if params else
        f"~pub tor {koru_name} {{}} -> string\n\n"
        f"~proc {koru_name}|zig {{\n{proc_body}\n}}\n"
    )


def _resolve_ref(prop: dict, defs: dict) -> list[str]:
    """Expand a $ref'd composite param into its declared fields — the same
    nested shape the stock arm's schema renders, flattened to one line."""
    ref = prop.get("$ref") or ""
    for item in prop.get("items", {}).get("anyOf", []):
        ref = ref or item.get("$ref", "")
    if not ref.startswith("#/$defs/"):
        return []
    shape = defs.get(ref.split("/")[-1], {})
    out = []
    for fname, fspec in shape.get("properties", {}).items():
        fdesc = fspec.get("description") or ""
        out.append(f"{fname}: {fspec.get('type', '?')}"
                   + (f" — {fdesc}" if fdesc else ""))
    return out


def _doc_for(name: str, tool: Tool) -> str:
    """One verb's contract block — every byte derived from openai_schema:
    function description, per-param type/description/enums, and the field
    shape of composite (JSON-in-string) params. Nothing authored."""
    fn = tool.openai_schema["function"]
    defs = fn.get("parameters", {}).get("$defs", {})
    props = {k: v for k, v in fn.get("parameters", {}).get("properties", {}).items()
             if k != "self"}
    koru_name = name.replace("_", "-")
    head = [f"{koru_name} — {fn.get('description', '').strip()}"]
    for p, spec in props.items():
        fields = _resolve_ref(spec, defs)
        if fields:
            shape = "; ".join(fields)
            head.append(f"  {p}: string holding JSON — {{{shape}}}")
            continue
        typ = spec.get("type")
        if typ is None or typ in ("array", "object") or "anyOf" in spec:
            typ = f"string holding JSON {typ or 'value'}"
        enum = spec.get("enum")
        line = f"  {p}: {typ}"
        if enum:
            line += " — one of " + " | ".join(str(e) for e in enum)
        desc = spec.get("description")
        if desc:
            line += f" — {desc.strip()}"
        head.append(line)
    return "\n".join(head)


# Fixed preamble — documents OUR interface's own verbs (say is the voice
# channel, the trio are gate introspection). Declared interface facts, not
# tau2 content and not behavioral guidance.
DOC_PREAMBLE = """\
# Tool contract — generated from the declared schema

Every entry below is translated verbatim from the tool schema the stock
interface advertises (descriptions, types, enums, nested field shapes).
A `string holding JSON` param carries a JSON array/object as one string —
the wire has no composite literals; escape inner quotes.

say(text: string) — the voice channel: what the user hears.
vocabulary() — list the verbs currently in scope.
grammar() — the wire's shape rules.
bind(name:, value:) — bind a datum into the session.
"""


def main() -> None:
    # Collect the @is_tool-decorated methods — the same set tau2 exposes.
    tors = []
    costs = {}
    for name, fn in inspect.getmembers(AirlineTools, inspect.isfunction):
        if name.startswith("_") or not getattr(fn, "__tool__", False):
            continue
        tool = Tool(func=fn)
        tors.append((name, tool))
        ttype = getattr(fn, "__tool_type__", ToolType.GENERIC)
        costs[name.replace("_", "-")] = 10 if ttype == ToolType.WRITE else 1

    if not tors:
        _die("no @is_tool methods found — is the decorator attribute "
             "'__tool__' still the marker? Check tau2 toolkit.py")

    out = [GENERATED_HEADER, SAY_TOR]
    out += [_emit_tor(n, t) for n, t in tors]
    reg = "\n".join(f"    {n.replace('_','-')}({costs[n.replace('_','-')]})"
                    for n, _ in tors)
    out.append(
        '~std/runtime:register(scope: "airline") {\n    say(1)\n'
        + reg + "\n}\n"
    )
    Path(__file__).with_name("airline_tools.kz").write_text("\n".join(out))
    print(f"generated {len(tors)} tors + say -> airline_tools.kz")

    doc = DOC_PREAMBLE + "\n" + "\n\n".join(_doc_for(n, t) for n, t in tors) + "\n"
    Path(__file__).with_name("airline_vocab_doc.md").write_text(doc)
    print(f"generated vocabulary doc -> airline_vocab_doc.md")


GENERATED_HEADER = """// airline_tools.kz — GENERATED by gen_airline_tors.py from tau2's
// openai_schema. Do not hand-edit: the gate's declared surface is the stock
// arm's schema read by construction, and drift is a generator bug, not a
// transcription to fix. Regenerate: ../tau2-bench/.venv/bin/python
// gen_airline_tors.py
//
// Structured tau2 arguments (flights, passengers, payment_methods) ride
// inside Koru STRING params as JSON — the wire has no composite literals.
// The register block vets the verb and the flat scalars; the proc splices
// JSON-carrying params raw so real arrays reach tau2's typed executor.
//
// Every tor returns its OWN PARSED INPUTS as a JSON string, so the gate's
// OK line carries arguments WITHOUT Python re-parsing Koru.

~import std/runtime

const std = @import("std");

// JSON-escape a runtime string for splicing inside a quoted JSON field.
// The wire parser resolves the model's escapes to real bytes; without
// this, a newline or quote lands inside the result JSON unescaped and the
// inner payload is not valid JSON (the marshal's parse then yields {}).
fn __jsonEsc(s: []const u8, buf: []u8) []const u8 {
    var i: usize = 0;
    for (s) |c| {
        if (c < 0x20 or c == '"' or c == '\\\\') {
            var tmp: [8]u8 = undefined;
            const rep: []const u8 = switch (c) {
                '"' => "\\\\\\"",
                '\\\\' => "\\\\\\\\",
                '\\n' => "\\\\n",
                '\\r' => "\\\\r",
                '\\t' => "\\\\t",
                else => std.fmt.bufPrint(&tmp, "\\\\u{x:0>4}", .{c}) catch "",
            };
            if (i + rep.len > buf.len) break;
            @memcpy(buf[i..][0..rep.len], rep);
            i += rep.len;
        } else {
            if (i >= buf.len) break;
            buf[i] = c;
            i += 1;
        }
    }
    return buf[0..i];
}
"""

# The voice channel is ours, not tau2's — every domain's refusal surface.
SAY_TOR = """// ============================================================================
// THE VOICE CHANNEL — the refusal surface (Koru's own, not a tau2 tool)
// ============================================================================

~pub tor say { text: string } -> string

~proc say|zig {
    const __S = struct { threadlocal var buf: [2048]u8 = undefined; };
    var __e0: [2048]u8 = undefined;
    const text_v = __jsonEsc(text, &__e0);
    const s = std.fmt.bufPrint(&__S.buf, "{{\\"text\\": \\"{s}\\"}}", .{text_v}) catch "{}";
    return s;
}
"""


if __name__ == "__main__":
    main()
