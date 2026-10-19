#!/bin/sh
# gen_airline.sh — regenerate airline_tools.k + airline_vocab_doc.md.
#
# dump_airline_schema.py marshals tau2's openai_schema to JSON (transport
# only); gen_airline.kz — a Koru program — owns every semantic decision:
# the type mapping (Source/Expression fields), name map, costs, doc text,
# the register block, the emitted proc plumbing.
set -eu
cd "$(dirname "$0")"

../../tau2-bench/.venv/bin/python dump_airline_schema.py

if [ ! -x gen_airline-binary ] || [ gen_airline.kz -nt gen_airline-binary ] \
    || [ airline_schema.json -nt gen_airline-binary ]; then
    echo "gen_airline.sh: building gen_airline-binary"
    koruc gen_airline.kz
    mv a.out gen_airline-binary
fi

./gen_airline-binary
