#!/bin/sh
# Hole 9 settler: every verb the grammar's worked example names must be in
# the scope's own vocabulary — on `calc`, `open`/`append` are not.
#   sh wired/holes/9_grammar_example_is_notes_shaped/settler.sh
set -u
cd "$(dirname "$0")"

koruc repro.k >/dev/null 2>&1 || { echo "HOLE 9 UNMEASURED: repro failed to build"; exit 2; }
out=$(./a.out 2>/dev/null) || { echo "HOLE 9 UNMEASURED: repro failed to run"; exit 2; }
rm -f a.out

# The worked example is the FIRST backticked fragment on the "Chain
# fresh outcomes" line (a later `` `h` `` is narration, not example).
# Pull the verb spellings out of it; empty extraction is unmeasured,
# never a pass.
verbs=$(printf '%s\n' "$out" | grep 'Chain fresh outcomes' | sed 's/[^`]*`//; s/`.*//' | grep -oE '[a-zA-Z_][a-zA-Z0-9_-]*[(]' | tr -d '(' | sort -u)
if [ -z "$verbs" ]; then
    echo "HOLE 9 UNMEASURED: no worked example found on the chain rule line"
    exit 2
fi

bad=""
for v in $verbs; do
    printf '%s\n' "$out" | grep -q "^${v}(" || bad="$bad $v"
done

if [ -n "$bad" ]; then
    echo "HOLE 9 OPEN: grammar example teaches verbs outside the vocabulary:$bad"
    exit 0
fi
echo "HOLE 9 CLOSED: every verb the example names is in the scope's vocabulary"
exit 1
