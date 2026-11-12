#!/bin/sh
# build-airline-gate.sh — rebuild the gate AND its compiled guide table.
#
# `std/guide:add` appends to `guide_table.txt` in the compile cwd (one line
# per add invocation), so a stale table must be removed first or every
# rebuild doubles the rows. The table lands beside the binaries, which is
# where `std/guide`'s lookup reads it from (`<exe dir>/guide_table.txt`) —
# both airline-gate-binary and tau-agent-binary live in this directory and
# share it.
set -eu
cd "$(dirname "$0")"

rm -f guide_table.txt
koruc airline-gate.k
mv a.out airline-gate-binary

if [ ! -s guide_table.txt ]; then
    echo "build-airline-gate: guide_table.txt missing — the guide module did not compile in" >&2
    exit 1
fi
echo "build-airline-gate: $(wc -l < guide_table.txt | tr -d ' ') guide rows"
shasum -a 256 guide_table.txt | cut -d' ' -f1
