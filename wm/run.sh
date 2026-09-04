#!/usr/bin/env bash
# wm/run.sh — kopium's world-model adapter (governed shape, ADAPTER kind).
#
# The target owns its layout knowledge: the two fast, deterministic,
# zero-token harnesses. The slow possession wall (900 forged closes,
# minutes) stays push-gated — watching runs cheap, gates run hard.
# Exit code speaks for the INSTRUMENTS; `signal` lines speak for the world.
set -euo pipefail
cd "$(dirname "$0")/../headless"

fail=0

if ./refusal-check.sh >/dev/null 2>&1; then
  echo "refusal gate: holds (3 pins)"
  echo "signal kopium.refusal.pins_held 3 pins"
else
  echo "refusal gate: BROKEN"
  echo "signal kopium.refusal.pins_held 0 pins"
  fail=1
fi

if koruc probe_multiline.k >/dev/null 2>&1 && ./a.out 2>&1 | grep -q "^many 2"; then
  echo "wire law: witnessed (many 2, head runs)"
  echo "signal kopium.wire.law_witnessed 1 flag"
else
  echo "wire law: NOT witnessed"
  echo "signal kopium.wire.law_witnessed 0 flag"
  fail=1
fi
rm -f a.out

# Cached builds don't touch it, but be explicit: the adapter never dirties sources.
git checkout -- build.zig.zon 2>/dev/null || true

exit "$fail"
