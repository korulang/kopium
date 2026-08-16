#!/bin/bash
# possession-check.sh — the possession claim as a gate.
#
# Builds and runs the dual-hold stress harness (stress-distinct.k) and passes
# its exit code through: 0 = possession held (all forged refusals accepted,
# both real handles accepted), 1 = possession broken. Nothing parses stdout —
# the harness's process exit IS the verdict, so this works unmodified as a CI
# step or status check.
#
# Usage:
#   ./possession-check.sh            # default volume (900)
#   ./possession-check.sh 100000     # explicit volume
#
# Requires koruc (see README.md — `zig build` in /Users/larsde/src/koru,
# symlinked to koruc on PATH) and the koru-libs checkout.

set -euo pipefail

cd "$(dirname "$0")"

volume="${1:-900}"

koruc stress-distinct.k
./a.out "$volume"