#!/bin/sh
# Hole 7 settler: a consume+reissue verb whose named-branch payloads carry
# the phantom must net ZERO pool records per call. Runs the committed probe;
# OPEN if post leaves 2 undischarged records (or the run panics), CLOSED if
# it nets 1 and the process exits clean.
#   sh wired/holes/7_branch_payload_creates_acquire_per_spec/settler.sh
set -u
cd "$(dirname "$0")/../../../headless"

koruc probe_ledger.k >/dev/null 2>&1 || { echo "HOLE 7 UNMEASURED: probe failed to compile"; exit 2; }
out=$(./a.out 2>&1); rc=$?

if printf '%s' "$out" | grep -q '\[post-ok\] result handles=1' && [ "$rc" -eq 0 ]; then
    echo "HOLE 7 CLOSED: post nets one record; probe exits clean"
    exit 1
fi

printf '%s\n' "$out" | grep -E '^\[post-ok\]|panic' | head -3
echo "HOLE 7 OPEN: branch-payload phantoms acquire per spec (exit $rc)"
exit 0
