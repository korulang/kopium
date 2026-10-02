#!/bin/bash
# refusal-check.sh — the refusal demonstrations as a gate.
#
# The live wire cannot produce refusals anymore: with `say()` available the
# model objects instead of forging, and the derived prompt leaves no drift.
# That is the agent working — but a demonstration whose coverage lives only
# in prose decays without a red anywhere. This gate pins both walls to the
# canned session (zero tokens, fully deterministic):
#
#   turn 3  forged handle  -> REFUSED possession denial, proc never runs
#   turn 6  undeclared verb -> DENIED at the vocabulary wall
#   hang-up compiler-written close still discharges the held note
#
# The process exit code IS the verdict (0 holds, 1 broken); stdout is never
# parsed for the verdict itself, only grepped for the three pins below.
#
# Usage:
#   ./refusal-check.sh
#
# Requires koruc (see README.md — `zig build` in /Users/larsde/src/koru,
# symlinked to koruc on PATH) and the koru-libs checkout.

set -euo pipefail

cd "$(dirname "$0")"

koruc session.k
# Both streams: the transcript prints to stdout, the bridge discharge to stderr.
out="$(./a.out 2>&1)"

fail=0
pin() {
    if ! grep -qF "$1" <<<"$out"; then
        echo "refusal gate: MISSING pin: $1" >&2
        fail=1
    fi
}

pin "names nothing the session holds"
pin "'close' never ran"
pin "DENIED — 'sync' is not in this agent's scope"
# The hang-up discharge: handles are OPAQUE (Lars ruling 09-07/08), so the
# pin matches any 6-hex mint — the claim is that the held note is released,
# never that a particular name is closed.
if ! grep -qE "\[BRIDGE\] Invoked 'close' for handle '[0-9a-f]{6}'" <<<"$out"; then
    echo "refusal gate: MISSING pin: [BRIDGE] Invoked 'close' for handle '<6-hex>'" >&2
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "refusal gate: holds — forged handle refused, drift denied, hang-up discharges."
fi
exit "$fail"
