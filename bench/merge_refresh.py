#!/usr/bin/env python3
"""Merge compare CSVs by task id into one refresh board.

  python3 merge_refresh.py OUT --from A.csv --from B.csv   # later files win

Same precedence rule as run_compare.py --stock-from: rows in later files
override earlier ones for the same task id. Rows are emitted sorted by
numeric task id.
"""
import csv
import sys
from pathlib import Path

out = None
sources = []
i = 1
while i < len(sys.argv):
    if sys.argv[i] == "--from":
        sources.append(Path(sys.argv[i + 1]))
        i += 2
    else:
        out = Path(sys.argv[i])
        i += 1

rows = {}
header = None
for src in sources:
    with open(src) as f:
        r = csv.reader(f)
        header = next(r)
        for row in r:
            rows[row[0]] = row

with open(out, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(header)
    for tid in sorted(rows, key=lambda t: int(t)):
        w.writerow(rows[tid])

done = len(rows)
kw = sum(1 for r in rows.values() if r[1] and float(r[1]) > 0)
sw = sum(1 for r in rows.values() if r[8] and float(r[8]) > 0)
print(f"{out}: {done} tasks, koru {kw}/{done} stock {sw}/{done}")
