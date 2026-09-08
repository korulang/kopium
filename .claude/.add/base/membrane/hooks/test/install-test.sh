#!/usr/bin/env bash
# Integration test: install the gate via install.sh into a throwaway repo, then
# drive REAL `git commit`s. Catches gaps the unit harness (hook-test.mjs) can't —
# it stubs the signal interface; this proves install.sh ships what the interlock
# needs. Run from anywhere: test/install-test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
INSTALL="$HERE/../install.sh"
TMP="$(mktemp -d)"; cd "$TMP"
git init -q; git config user.email t@t; git config user.name t
bash "$INSTALL" "$TMP" >/dev/null 2>&1

pass=0; fail=0
check() { # <expect accept|reject> <label> <message>   (files pre-staged); no pipe → parent shell
  local expect="$1" label="$2" msg="$3" got
  if git commit -q -F <(printf '%s' "$msg") >/dev/null 2>/tmp/it_err; then got=accept; else got=reject; fi
  if [ "$got" = "$expect" ]; then echo "  ✓ $label [$expect]"; pass=$((pass+1));
  else echo "  ✗ $label [expect $expect, got $got]"; sed 's/^/      /' /tmp/it_err; fail=$((fail+1)); fi
}

echo x > a.txt; git add a.txt
check reject "no ## Membrane section" \
  $'feat: a\n\n## World Model\nSignals: acknowledged-none\n'

check accept "routine (both acknowledged-none)" \
  $'feat: a\n\n## World Model\nSignals: acknowledged-none\n\n## Membrane\nEvolution: acknowledged-none\n'

echo y > b.txt; git add b.txt
check reject "interlock: belief signal forbids acknowledged-none" \
  $'feat: b\n\n## World Model\nSignal: contradiction — X flipped\n\n## Membrane\nEvolution: acknowledged-none\n'

mkdir -p concepts; echo "belief" > concepts/frag-t.md; git add concepts/frag-t.md
check accept "interlock satisfied: belief signal + gardened create" \
  $'feat: b\n\n## World Model\nSignal: contradiction — X flipped\n\n## Membrane\nAction: create\nConcept: frag-t\n'

echo; echo "  $pass/$((pass+fail)) passed"
cd /; rm -rf "$TMP" /tmp/it_err
[ "$fail" -eq 0 ]
