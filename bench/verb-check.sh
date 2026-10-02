#!/bin/sh
# verb-check.sh — deterministic airline verb exerciser driver (no model,
# no Python). Builds bench/verb-check.k if needed, feeds it the canned
# inbound stream bench/verb-check.stdin.jsonl, and captures stdout split by
# prefix into results/verb-check/:
#
#   outbound.jsonl — lines beginning {"kind":  (the protocol lines the
#                    generated procs emitted; calls carry ids k1..k14,
#                    say carries no id)
#   values.txt     — lines beginning VALUE / FAIL- (the per-run stringified
#                    result value, or the failure arm marker)
#   stderr.log     — everything the binary logged to stderr
#
# Fixture: verb-check.fixture.jsonl, one JSON object per verb:
#   {"verb":<koru name>,"tau_name":<tau2 name|null>,"task":<id|null>,
#    "source":<wire line the program runs>,"args":{<expected tau2 args>}}
# `task` is the tasks.json id the args were lifted from; null = schema-minimal.
set -eu
cd "$(dirname "$0")"

# Variant: `./verb-check.sh native` builds verb-check-native.k against the
# airline-native scope and reads verb-check-native.{fixture,stdin}.jsonl;
# bare `./verb-check.sh` is the transliterated arm, unchanged.
VARIANT="${1:-}"
BASE="verb-check"
[ -n "$VARIANT" ] && BASE="verb-check-$VARIANT"
OUT="results/$BASE"

if [ ! -x "$BASE-binary" ] || [ "$BASE.k" -nt "$BASE-binary" ]; then
    echo "verb-check.sh: building $BASE-binary"
    koruc "$BASE.k"
    mv a.out "$BASE-binary"
fi

mkdir -p "$OUT"
"./$BASE-binary" < "$BASE.stdin.jsonl" > "$OUT/stdout.txt" \
    2> "$OUT/stderr.log"

grep '^{"kind":' "$OUT/stdout.txt" > "$OUT/outbound.jsonl" || true
grep -v '^{"kind":' "$OUT/stdout.txt" > "$OUT/values.txt" || true

echo "outbound lines: $(wc -l < "$OUT/outbound.jsonl" | tr -d ' ')"
echo "value lines:    $(wc -l < "$OUT/values.txt" | tr -d ' ')"
echo "wrote $OUT/{outbound.jsonl,values.txt,stdout.txt,stderr.log}"
