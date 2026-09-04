#!/usr/bin/env bash
# wm/faucet.sh — kopium's adapter→bus faucet (the NATS leg).
#
# Runs wm/run.sh, then publishes every `signal <name> <value> [unit]` line
# to NATS JetStream subject world.signal.<name> (stream SIGNALS).
# Shape copied from the membrane post-commit faucet: best-effort,
# non-blocking, LOUD on failure (a signal that never reached the bus is
# a DROPPED signal). The adapter's exit code is preserved — exit speaks
# for the instruments, signals speak for the world.
#
# Backend-pretend, stated honestly: if NATS is down, the run record still
# holds the signals (wm last) and the drop screams on stderr. JetStream
# is the replay substrate — no separate replay surface to build.
#
# Usage: wm/faucet.sh [--no-publish] [-- <adapter args...>]
set -uo pipefail
cd "$(dirname "$0")"

PUBLISH=1
ARGS=()
for a in "$@"; do
  case "$a" in
    --no-publish) PUBLISH=0 ;;
    --) ;;
    *) ARGS+=("$a") ;;
  esac
done

tmp="$(mktemp)"
./run.sh "${ARGS[@]:-}" >"$tmp" 2>&1
code=$?
cat "$tmp"

server="${CLAUDE_NATS:-${NATS_URL:-127.0.0.1:4222}}"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

publish_one() {
  local name="$1" value="$2" unit="$3"
  local payload
  payload="$(SIGNAL_NAME="$name" SIGNAL_VALUE="$value" SIGNAL_UNIT="$unit" SIGNAL_NOW="$now" python3 -c '
import json, os
v = os.environ["SIGNAL_VALUE"]
try: v = int(v)
except ValueError:
    try: v = float(v)
    except ValueError: pass
u = os.environ["SIGNAL_UNIT"]
doc = {"name": os.environ["SIGNAL_NAME"], "kind": "measured",
       "value": v, "source": "kopium-wm-faucet", "repo": "kopium",
       "at": os.environ["SIGNAL_NOW"]}
if u: doc["unit"] = u
print(json.dumps(doc))')"
  if ! timeout 4 nats --server "$server" pub "world.signal.${name}" "$payload" >/dev/null 2>&1; then
    echo "⚠ faucet: signal '${name}' did NOT reach the bus (nats ${server}) — card DROPPED (bus down?)." >&2
  fi
}

if [ "$PUBLISH" = 1 ]; then
  if ! command -v nats >/dev/null 2>&1; then
    echo "⚠ faucet: 'nats' CLI not on PATH — cards DROPPED (run record still holds the signals)." >&2
  else
    while read -r _ name value unit; do
      [ -n "${name:-}" ] || continue
      publish_one "$name" "$value" "${unit:-}" &
    done < <(grep -E '^signal [A-Za-z0-9._-]+ [^ ]+( .+)?$' "$tmp" || true)
    wait
  fi
fi

rm -f "$tmp"
exit "$code"
