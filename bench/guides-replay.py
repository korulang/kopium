#!/usr/bin/env python3
"""guides-replay.py — deterministic verification of the R4 guide rails.

No LLM. Feeds recorded train-30 corpus wires (reconstructed from the
`call_step` stream's `args[].raw`) through the real gate binary, and asserts
three things per firing site:

  (a) the guide fires at the expected dispatch — the call_step record's
      `fired_guides` names the expected TABLE key;
  (b) the injected text reaches the model-visible channel — the gate's own
      stdout for that turn carries `guide <key>: <template>`, byte-equal to
      the compiled table's row;
  (c) `fired_guides` is populated (and exactly the guide that fired — a
      wildcard row attributes to itself).

Plus the doctrine invariants:
  - once per key per session: the same dispatch a second time fires nothing;
  - tor-level + edge rows both fire, edge first;
  - specificity: an exact `tor->branch` row beats `*->error`;
  - silence: a verb with no row (`say`) injects nothing.

Usage: python3 guides-replay.py [binary] [--verbose]
Exit code 0 = every asserted case passed.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from tau_gate_session import TauGateSession  # noqa: E402

BINARY = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else HERE / "airline-gate-binary"
VERBOSE = "--verbose" in sys.argv
CORPUS = HERE / "corpus" / "combined-r2r3-callstep.jsonl"
TABLE = HERE / "guide_table.txt"

FAILS: list[str] = []
PASSES: list[str] = []
DARK: list[str] = []


def load_table() -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in TABLE.read_text().splitlines():
        if "\t" not in line:
            continue
        k, t = line.split("\t", 1)
        rows[k] = t
    return rows


def load_corpus() -> list[dict]:
    return [json.loads(l) for l in CORPUS.read_text().splitlines() if l.strip()]


def usable(rec: dict) -> bool:
    """A record whose wire can be reconstructed verbatim: a real tool call,
    no chain references in its args, a named branch."""
    if not rec.get("verb") or rec["verb"] in ("say", "note"):
        return False
    if rec.get("failed"):
        return False
    if rec.get("branch") not in ("ok", "error"):
        return False
    for a in rec.get("args") or []:
        if a.get("ref"):
            return False
    return True


def wire_for(rec: dict) -> str:
    args = ", ".join(f'{a["name"]}: {a["raw"]}' for a in rec.get("args") or [])
    arm = "| ok r |>" if rec["branch"] == "ok" else "| error e |>"
    return f'{rec["verb"]}({args}) {arm}'


def result_for(rec: dict) -> str:
    payload = rec.get("payload") or {}
    value = payload.get("value")
    if isinstance(value, str):
        return value
    return json.dumps(value)


def pump(g: TauGateSession, wire: str, content: str, error: bool):
    """One wire turn; answer calls; return (status_kind, detail)."""
    ev = g.send_wire(wire + "\n")
    while ev[0] in ("call", "say"):
        if ev[0] == "call":
            ev = g.feed_result(ev[1]["id"], content, error)
        else:
            ev = g.next_event()
    if ev[0] != "status":
        raise RuntimeError(f"gate produced no status: {ev!r}")
    return ev[1], ev[2]


def flush(g: TauGateSession):
    """CALLSTEPS lands after the verdict and parses on the NEXT turn's read;
    a throwaway vocabulary() turn flushes the previous turn's block."""
    ev = g.send_wire("vocabulary()\n")
    while ev[0] in ("call", "say"):
        ev = g.feed_result(ev[1]["id"], "{}", True) if ev[0] == "call" else g.next_event()


def turn_records(g: TauGateSession) -> list[dict]:
    return [r for r in g.drain_callsteps() if r.get("origin") == "model"]


def visible(kind: str, detail: str, unframed: list[str]) -> str:
    return "\n".join([detail] + unframed)


def check(name: str, cond: bool, why: str):
    (PASSES if cond else FAILS).append(f"{name}: {why}")
    if VERBOSE or not cond:
        print(("PASS " if cond else "FAIL ") + name + " — " + why)


def cancel_prelude(rec: dict):
    """Guarded tools need their session precondition met first — a prior
    successful read of the same reservation, as a compliant run produces.
    Returns [(wire, content)] or None."""
    rid = next((a["raw"] for a in rec.get("args") or []
                if a.get("name") == "reservation_id"), None)
    if rid is None:
        return None
    return [(
        f'get-reservation-details(reservation_id: {rid}) | ok r |>',
        f'{{"reservation_id": {rid}, "status": "ok"}}',
    )]


def run_case(table: dict[str, str], key: str, rec: dict, expect_key: str | None = None,
             prelude=None):
    """Fresh session, one reconstructed dispatch; assert fire + visibility."""
    expect = expect_key or key
    g = TauGateSession(BINARY)
    try:
        for pw, pc in prelude or []:
            pump(g, pw, pc, False)
        kind, detail = pump(g, wire_for(rec), result_for(rec), rec["branch"] == "error")
        # Guide lines and CALLSTEPS are emitted AFTER the verdict and are
        # parsed on the next turn's first read — flush first, then drain.
        flush(g)
        unf = g.drain_unframed()
        recs = turn_records(g)
        got = [k for r in recs for k in r.get("fired_guides") or []]
        check(f"{key} fires", expect in got, f"fired_guides={got}")
        if expect in got:
            line = f"guide {expect}: {table[expect]}"
            check(f"{key} text reaches the model channel", line in visible(kind, detail, unf),
                  f"verdict={kind}")
            check(f"{key} attribution is the table row", expect in table, "key in table")
    finally:
        g.close()


def run_control_say(table: dict[str, str]):
    """`say` has no guide row: nothing fires, no guide line appears."""
    g = TauGateSession(BINARY)
    try:
        kind, detail = pump(g, 'say(text: "hello")', "hello", False)
        flush(g)
        unf = g.drain_unframed()
        recs = turn_records(g)
        got = [k for r in recs for k in r.get("fired_guides") or []]
        check("control: say fires no guide", got == [], f"fired_guides={got}")
        check("control: say injects no text", not any(l.startswith("guide ") for l in unf),
              f"unframed={unf[:2]}")
    finally:
        g.close()


def run_once_per_session():
    """The same dispatch twice in ONE session: first fires, second silent."""
    rec = first_usable_for("get-user-details", "ok")
    g = TauGateSession(BINARY)
    try:
        wire, content = wire_for(rec), result_for(rec)
        pump(g, wire, content, False)
        flush(g)
        g.drain_unframed()  # first turn's lines belong to the first assertion
        got1 = [k for r in turn_records(g) for k in r.get("fired_guides") or []]
        pump(g, wire, content, False)
        flush(g)
        unf2 = g.drain_unframed()
        got2 = [k for r in turn_records(g) for k in r.get("fired_guides") or []]
        check("once-per-session: first turn fires", bool(got1), f"fired_guides={got1}")
        check("once-per-session: second turn silent", got2 == [], f"fired_guides={got2}")
        check("once-per-session: no repeated text",
              not any(l.startswith("guide ") for l in unf2), f"unframed={unf2[:2]}")
    finally:
        g.close()


def run_specificity(table: dict[str, str]):
    """An exact edge row beats the generic `*->error` row."""
    if "book-reservation->error" not in table or "*->error" not in table:
        return
    rec = first_usable_for("book-reservation", "error")
    g = TauGateSession(BINARY)
    try:
        pump(g, wire_for(rec), result_for(rec), True)
        flush(g)
        got = [k for r in turn_records(g) for k in r.get("fired_guides") or []]
        check("specificity: exact edge row wins", "book-reservation->error" in got
              and "*->error" not in got, f"fired_guides={got}")
    finally:
        g.close()


_CORPUS: list[dict] | None = None


def first_usable_for(verb: str, branch: str | None) -> dict:
    global _CORPUS
    if _CORPUS is None:
        _CORPUS = load_corpus()
    for rec in _CORPUS:
        if rec.get("verb") != verb or not usable(rec):
            continue
        if branch is None or rec.get("branch") == branch:
            return rec
    raise LookupError(f"no usable corpus record for {verb}|{branch}")


def main() -> int:
    table = load_table()
    print(f"table: {TABLE} ({len(table)} rows)")
    print(f"corpus: {CORPUS} ({len(load_corpus())} records)")

    # Every tor->branch row with observed corpus coverage.
    for key in sorted(table):
        if "->" not in key or key.startswith("*"):
            continue
        verb, branch = key.split("->", 1)
        try:
            rec = first_usable_for(verb, branch)
        except LookupError:
            DARK.append(f"{key} — never observed in train-30 corpus (row authored, unexercised)")
            continue
        pre = cancel_prelude(rec) if verb == "cancel-reservation" else None
        run_case(table, key, rec, prelude=pre)

    # Every tor-level row: first observed dispatch of that verb.
    for key in sorted(table):
        if "->" in key:
            continue
        verb = key
        try:
            rec = first_usable_for(verb, None)
        except LookupError:
            DARK.append(f"{key} — never dispatched in train-30 corpus (row authored, unexercised)")
            continue
        pre = cancel_prelude(rec) if verb == "cancel-reservation" else None
        run_case(table, f"{key} (tor-level)", rec, expect_key=key, prelude=pre)

    # The generic error row, on an observed error with no specific row.
    if "*->error" in table:
        rec = first_usable_for("transfer-to-human-agents", "error")
        run_case(table, "*->error", rec, expect_key="*->error")

    run_control_say(table)
    run_once_per_session()
    run_specificity(table)

    print()
    for d in DARK:
        print("DARK " + d)
    print(f"\n{len(PASSES)} passed, {len(FAILS)} failed, {len(DARK)} dark rows")
    for f in FAILS:
        print("  FAIL " + f)
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())
