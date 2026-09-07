#!/bin/sh
# Settler for hole 6: the ONLY stdlib file-write tor cannot refuse creation.
# Compiles a std-only probe (no app imports, no network, no model) that calls
# std/fs:write on a path that does not exist. If the toolchain ever gains a
# refusal arm (exists/refused/…) this settler flips: exit 0 means the hole
# is OPEN (missing file created, arm `written`), exit 1 means CLOSED.
set -e
HEADLESS="$(cd "$(dirname "$0")/../../../headless" && pwd)"
cd "$HEADLESS"
SCRATCH="$HEADLESS/.hole6_scratch.txt"
PROBE="$HEADLESS/.hole6_settler.k"
rm -f "$SCRATCH"
cat > "$PROBE" <<'KORU'
import std/io
import std/fs
std/fs:write(path: ".hole6_scratch.txt", content: "created by stdlib, not refused")
| written |> std/io:print.ln("SETTLER: missing file was CREATED, arm written")
| failed e |> std/io:print.ln("SETTLER: refused")
KORU
koruc .hole6_settler.k > /dev/null 2>&1
./a.out > .hole6_out.txt 2>&1
rm -f "$PROBE"
if [ -f "$SCRATCH" ] && grep -q "CREATED" .hole6_out.txt; then
  echo "HOLE 6 OPEN: std/fs:write created the missing file (arm written, no refusal)"
  rm -f "$SCRATCH" .hole6_out.txt
  exit 0
else
  echo "HOLE 6 CLOSED: std/fs:write refused the missing file"
  rm -f "$SCRATCH" .hole6_out.txt
  exit 1
fi
