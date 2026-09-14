#!/bin/sh
# Hole 8 settler: a vocabulary module may name its state `name_len` without
# colliding with the generated dispatcher's locals.
#   sh wired/holes/8_dispatcher_locals_collide_with_module_state/settler.sh
set -u
cd "$(dirname "$0")"

if koruc repro.k >/dev/null 2>&1 && ./a.out >/dev/null 2>&1; then
    rm -f a.out
    echo "HOLE 8 CLOSED: module-level name_len no longer collides"
    exit 1
fi

echo "HOLE 8 OPEN: generated dispatch locals shadow module state (name_len)"
exit 0
