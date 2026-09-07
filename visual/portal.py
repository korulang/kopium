#!/usr/bin/env python3
"""kopium transcript portal — one small local page over the challenge catalogs.

No build step, no deps: renders markdown on the fly from disk, so the page is
always current with the shelf. Zero friction — a new catalog entry appears with
no integration work, the same pit-of-success the challenges themselves obey.

    python3 visual/portal.py [port]     # default 8137
"""
from __future__ import annotations

import html
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
CHALLENGES = ROOT / "challenges"


def md_to_html(text: str) -> str:
    out: list[str] = []
    in_pre = False
    para: list[str] = []
    def flush_para() -> None:
        if para:
            body = " ".join(para)
            body = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", body)
            body = re.sub(r"`([^`]+)`", r"<code>\1</code>", body)
            out.append(f"<p>{body}</p>")
            para.clear()
    for line in text.splitlines():
        if line.strip().startswith("```"):
            flush_para()
            out.append("<pre>" if not in_pre else "</pre>")
            in_pre = not in_pre
            continue
        if in_pre:
            out.append(html.escape(line))
            continue
        if not line.strip():
            flush_para()
            continue
        m = re.match(r"^(#{1,4})\s+(.*)", line)
        if m:
            flush_para()
            lvl, title = len(m.group(1)), html.escape(m.group(2))
            out.append(f"<h{lvl}>{title}</h{lvl}>")
            continue
        if re.match(r"^(\*|-|[0-9]+\.)\s+", line):
            flush_para()
            item = re.sub(r"^(\*|-|[0-9]+\.)\s+", "", line)
            item = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html.escape(item))
            item = re.sub(r"`([^`]+)`", r"<code>\1</code>", item)
            out.append(f"<div class='li'>{item}</div>")
            continue
        para.append(html.escape(line))
    flush_para()
    if in_pre:
        out.append("</pre>")
    return "\n".join(out)


PAGE = """<!doctype html><html><head><meta charset="utf-8">
<title>{title}</title><style>
body{{font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:880px;margin:2em auto;
padding:0 1.2em;line-height:1.55;color:#e8e4d8;background:#161511}}
h1{{font-size:1.5em}}h2{{font-size:1.2em;margin-top:1.6em}}
pre{{background:#242219;padding:1em;overflow-x:auto;font-size:.85em;border-radius:6px}}
code{{background:#242219;padding:.1em .3em;border-radius:3px;font-size:.9em}}
a{{color:#7aa7e8;text-decoration:none}}a:hover{{text-decoration:underline}}
.li{{margin:.25em 0 .25em 1.2em}}.nav{{margin-bottom:1.5em;font-size:.9em;color:#999}}
.card{{border:1px solid #3a382c;border-radius:8px;padding:.8em 1em;margin:.7em 0;background:#1e1d16}}
.stamp{{font-size:.8em;color:#888}}
.turn{{border:1px solid #3a382c;border-radius:8px;padding:.7em 1em;margin:.7em 0;background:#1e1d16;border-left-width:4px;word-break:break-word}}
.turn.ok{{border-left-color:#4d7c4d}}.turn.defined{{border-left-color:#c9a227}}
.turn.refused{{border-left-color:#b0413e}}.turn.denied{{border-left-color:#b06a2c}}.turn.info{{border-left-color:#555}}
.thead{{font-weight:600;margin-bottom:.4em}}.tno{{color:#888;font-weight:400;margin-right:.5em}}
.badge{{font-size:.75em;font-weight:400;border-radius:4px;padding:.1em .5em;margin-left:.6em;vertical-align:middle;white-space:nowrap}}
.badge.ok{{background:#233823;color:#9fd19f}}.badge.defined{{background:#3a3214;color:#e8c84a}}
.badge.refused{{background:#3d1d1c;color:#e89a97}}.badge.denied{{background:#3a2a14;color:#e0a75e}}.badge.info{{background:#2a2a2a;color:#aaa}}
.src{{background:#242219;padding:.6em 1em;overflow-x:auto;font-size:.85em;border-radius:6px;white-space:pre-wrap}}
.outcome{{margin:.4em 0;font-size:.92em}}.usage{{font-size:.8em;color:#888}}
.res{{height:1.2em;background:#242219;border-radius:4px;position:relative;margin:.4em 0}}
.res .bar{{position:absolute;left:0;top:0;bottom:0;background:#4d6a8a;border-radius:4px}}
.res span{{position:relative;font-size:.75em;color:#ccc;padding-left:.5em;line-height:1.6}}
.chips{{margin:.4em 0}}.chip{{display:inline-block;border:1px solid #3a382c;border-radius:20px;padding:.1em .8em;margin:.15em;font-size:.85em;font-family:monospace}}
.chip.new{{border-color:#c9a227;color:#e8c84a}}
@media (prefers-color-scheme: light){{
body{{color:#1a1a1a;background:#fdfcf8}}
pre,code{{background:#f2efe6}}a{{color:#1a5fb4}}.nav,.stamp{{color:#666}}
.card{{border-color:#ddd;background:#fff}}}}
</style></head><body><div class="nav"><a href="/">catalogs</a> · kopium transcripts</div>
{body}</body></html>"""


def entries() -> list[tuple[str, str, list[tuple[str, Path]]]]:
    """[(challenge, brief_path, [(label, md_path)])] — every shelf shape."""
    out = []
    for ch_dir in sorted(p for p in CHALLENGES.iterdir() if p.is_dir()):
        brief = ch_dir / "CHALLENGE.md"
        cat = ch_dir / "catalog"
        items: list[tuple[str, Path]] = []
        if cat.is_dir():
            for p in sorted(cat.iterdir()):
                if p.is_dir():
                    for f in sorted(p.glob("*.md")):
                        items.append((f"{p.name}/{f.stem}", f))
                elif p.suffix == ".md":
                    items.append((p.stem, p))
        out.append((ch_dir.name, brief, items))
    return out

# ---------------------------------------------------------------------------
# KOPIUM runs — turn timelines parsed from real run transcripts on disk.
#
# Feed: `*.transcript.txt` saved next to the program that printed it
# (headless/session.transcript.txt, headless/live-define.transcript.txt, ...).
# Save a run's stdout there and it appears on the index with no integration
# work — the same pit-of-success as the challenge shelves. The parser only
# recognizes the shapes session.k / live.k / the bench probes actually print
# (turn blocks, `--- N. section ---` blocks, derived-vocabulary renders);
# anything else renders raw, never as a faked timeline.
# ---------------------------------------------------------------------------

RUN_DIRS = (ROOT / "headless", ROOT / "bench")

TURN_RE = re.compile(r"^turn (\d+)\s+(?:model wants to:\s?|goal:\s?)?(.*)$")
SECTION_RE = re.compile(r"^---\s*(\d+)\.\s*(.*?)\s*---\s*$")
MARKER_RE = re.compile(r"^---\s*(.*?)\s*---\s*$")
TOOL_RE = re.compile(r"^\s+(?:tool|model)>\s?(.*)$")
CLEANED_RE = re.compile(r"^cleaned>\s?(.*)$")
RAW_RE = re.compile(r"^\s*raw\s+>\s?\[.*\]\s*$")
HOLDS_RE = re.compile(r"holds (\d+) resource")
DEFINED_RE = re.compile(r"^[Dd]efined\s+(\S+)")
USAGE_RE = re.compile(r"\[usage\]\s?(.*)")

RUN_LABEL = ".transcript"


def run_key(f: Path) -> str:
    stem = f.stem
    return stem[:-len(RUN_LABEL)] if stem.endswith(RUN_LABEL) else stem


def runs() -> list[Path]:
    out: list[Path] = []
    for d in RUN_DIRS:
        if d.is_dir():
            out.extend(sorted(d.glob("*.transcript.txt")))
    return out


def _new_step(kind: str, n: str, title: str) -> dict:
    return {"kind": kind, "n": n, "title": title.strip(), "source": [],
            "out": [], "usage": None, "handles": None, "defined": []}


def parse_run(text: str) -> tuple[list[dict], list[str], list[str]]:
    steps: list[dict] = []
    vocab: list[str] = []
    footer: list[str] = []
    cur: dict | None = None
    mode = "steps"

    def flush() -> None:
        nonlocal cur
        if cur is not None:
            steps.append(cur)
            cur = None

    for raw in text.splitlines():
        line = raw.rstrip()
        s = line.strip()
        if not s:
            continue
        m = TURN_RE.match(s) or SECTION_RE.match(s)
        if m:
            if "derived vocabulary" in m.group(2).lower():
                flush()
                mode = "vocab"
                continue
            flush()
            cur = _new_step("turn" if s.startswith("turn") else "step",
                            m.group(1), m.group(2))
            mode = "steps"
            continue
        if MARKER_RE.match(s):
            label = s.strip("- ").lower()
            if "derived vocabulary" in label:
                flush()
                mode = "vocab"
                continue
            flush()
            mode = "steps"
            if "session open" in label or "canned" in label:
                footer.append(s.strip("- ").strip())
            continue
        if mode == "vocab":
            vocab.append(s)
            continue
        if cur is None:
            footer.append(s)
            continue
        tm = TOOL_RE.match(line) or CLEANED_RE.match(line)
        if tm:
            cur["source"].append(tm.group(1))
            continue
        if RAW_RE.match(line):
            continue
        um = USAGE_RE.search(s)
        if um:
            cur["usage"] = um.group(1).strip()
            continue
        dm = DEFINED_RE.search(s)
        if dm:
            cur["defined"].append(dm.group(1).strip("—–-:;,"))
            cur["out"].append(s)
            continue
        hm = HOLDS_RE.search(s)
        if hm:
            cur["handles"] = int(hm.group(1))
            cur["out"].append(s)
            continue
        if ("REFUSED" in s or "DENIED" in s or " ran —" in s
                or s.startswith("[") or line.startswith((" ", "\t"))):
            cur["out"].append(s)
            continue
        if cur["source"] and not cur["out"] and ("(" in s or "=" in s):
            cur["source"].append(s)
            continue
        cur["out"].append(s)
    flush()
    return steps, vocab, footer


def classify(st: dict) -> tuple[str, str]:
    o = " ".join(st["out"])
    if st["defined"]:
        return ("defined", "defined")
    if "REFUSED" in o:
        return ("refused", "REFUSED")
    if "DENIED" in o:
        return ("denied", "DENIED")
    if st["handles"] is not None or " ran —" in o:
        return ("ok", "ok")
    return ("info", "note")


def render_run_page(path: Path) -> str:
    text = path.read_text()
    steps, vocab, footer = parse_run(text)
    if not steps and not vocab:
        return (f"<h1>{html.escape(run_key(path))}</h1>"
                f"<div class='stamp'>{html.escape(str(path.relative_to(ROOT)))} · unparsed — raw log</div>"
                f"<pre>{html.escape(text)}</pre>")
    defined_names = sorted({w for st in steps for w in st["defined"]})
    maxh = max([st["handles"] for st in steps if st["handles"] is not None] + [0])
    parts = [f"<h1>{html.escape(run_key(path))}</h1>",
             f"<div class='stamp'>{html.escape(str(path.relative_to(ROOT)))} · {len(steps)} steps"
             + (f" · defines {html.escape(', '.join(defined_names))}" if defined_names else "") + "</div>"]
    for st in steps:
        cls, label = classify(st)
        head = (f"<div class='thead'><span class='tno'>{html.escape(st['kind'])} {html.escape(str(st['n']))}</span>"
                f"{html.escape(st['title'])}<span class='badge {cls}'>{label}</span></div>")
        body = ""
        if st["source"]:
            body += f"<pre class='src'>{html.escape(chr(10).join(st['source']))}</pre>"
        for o in st["out"]:
            body += f"<div class='outcome'>{html.escape(o)}</div>"
        if st["usage"]:
            body += f"<div class='usage'>usage {html.escape(st['usage'])}</div>"
        if st["handles"] is not None:
            pct = (100 * st["handles"] // maxh) if maxh else 0
            body += (f"<div class='res'><div class='bar' style='width:{pct}%'></div>"
                     f"<span>bridge holds {st['handles']} resource(s)</span></div>")
        parts.append(f"<div class='turn {cls}'>{head}{body}</div>")
    if vocab:
        chips = "".join(
            f"<span class='chip{' new' if v.split('(')[0].strip() in defined_names else ''}'>{html.escape(v)}</span>"
            for v in vocab)
        parts.append(f"<h2>derived vocabulary</h2><div class='chips'>{chips}</div>")
    if footer:
        parts.append("<h2>log</h2><pre>" + html.escape(chr(10).join(footer)) + "</pre>")
    return chr(10).join(parts)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a) -> None:
        pass

    def send_page(self, title: str, body: str) -> None:
        data = PAGE.format(title=html.escape(title), body=body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        path = unquote(self.path.split("?", 1)[0])
        if path in ("/", ""):
            parts = ["<h1>transcript catalogs</h1>"]
            run_files = runs()
            if run_files:
                rcards = []
                for f in run_files:
                    steps, _, _ = parse_run(f.read_text())
                    defs = sorted({w for st in steps for w in st["defined"]})
                    sub = f"{len(steps)} steps" + (f" · defines {', '.join(defs)}" if defs else "")
                    rcards.append(
                        f"<div class='card'><a href='/r/{html.escape(run_key(f))}'>{html.escape(run_key(f))}</a>"
                        f" <span class='stamp'>{html.escape(sub)} · {html.escape(str(f.relative_to(ROOT)))}</span></div>")
                parts.append("<h2>kopium runs <span class='stamp'>turns · resources · vocabulary</span></h2>" + "".join(rcards))
            for ch, _, items in entries():
                cards = "".join(
                    f"<div class='card'><a href='/v/{ch}/{html.escape(lbl)}'>"
                    f"{html.escape(lbl)}</a></div>"
                    for lbl, _ in items
                ) or "<div class='card'>empty shelf</div>"
                parts.append(f"<h2>{html.escape(ch)} <span class='stamp'>{len(items)}</span></h2>{cards}")
            self.send_page("kopium catalogs", "\n".join(parts))
            return
        m = re.match(r"^/v/([^/]+)/(.+)$", path)
        if m:
            ch, lbl = m.group(1), m.group(2)
            for name, _, items in entries():
                if name == ch:
                    for label, f in items:
                        if label == lbl and f.is_file():
                            self.send_page(
                                f"{ch} · {lbl}",
                                f"<h1>{html.escape(lbl)}</h1>"
                                f"<div class='stamp'>{html.escape(str(f.relative_to(ROOT)))}</div>"
                                + md_to_html(f.read_text()),
                            )
                            return
        m2 = re.match(r"^/r/([^/]+)$", path)
        if m2:
            target = next((f for f in runs() if run_key(f) == m2.group(1)), None)
            if target is not None and target.is_file():
                self.send_page(f"run · {run_key(target)}", render_run_page(target))
                return
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(404)
        self.end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8137
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
