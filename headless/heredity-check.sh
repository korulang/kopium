#!/bin/bash
# heredity-check.sh — the world-inheritance demonstration as a gate.
#
# session.k pins that a verb invented mid-session works IN that session.
# This gate pins the rung above: a verb session A invented works in session
# B, a different bridge on the same world dir — and a verb nobody persisted
# is still denied. Zero tokens, fully deterministic.
#
#   A.4  the composite define lands AND persists to world/log-line.k
#   B.1  the inherited verb dispatches in a session that never defined it
#   B.2  an unpersisted verb is still DENIED at the vocabulary wall
#   vocab  the derived vocabulary — the prompt's own source — lists log-line
#
# The process exit code IS the verdict (0 holds, 1 broken).
#
# Usage:
#   ./heredity-check.sh
#
# Requires koruc (see README.md) and the koru-libs checkout.

set -euo pipefail

cd "$(dirname "$0")"

rm -rf world agent-log.txt
koruc heredity.k
out="$(./a.out 2>&1)"

fail=0
pin() {
    if ! grep -qF "$1" <<<"$out"; then
        echo "heredity gate: MISSING pin: $1" >&2
        fail=1
    fi
}

# The defined/denied report lines come from app/agent:act — the shared
# verdict dispatch. Persistence is witnessed by the world file pin below
# and by session B inheriting, not by this line's wording.
pin "defined log-line — the session's vocabulary now includes it"
pin "log-line(path: string, text: string)"
pin "DENIED — 'greet' is not in this agent's scope"

# The inherited dispatch: everything after "session B open" is B's run —
# the composite must actually have executed there, not just been listed.
b_out="$(awk '/session B open/,0' <<<"$out")"
if ! grep -q "note closed, fd released" <<<"$b_out"; then
    echo "heredity gate: MISSING pin: log-line dispatched inside session B" >&2
    fail=1
fi

# The genome is a directory of programs — the persisted source is verbatim.
if ! grep -qF 'log-line = open(path)' world/log-line.k 2>/dev/null; then
    echo "heredity gate: MISSING pin: world/log-line.k holds the composite body" >&2
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "heredity gate: holds — session B inherited, dispatched, and the wall still refuses."
fi
exit "$fail"
