// probe_observer.k — pins the bounded observer-residue exemption
// (task28 2026-10-05: 246 exempt observer residues until the 900s
// watchdog). One free observer answer per edge question; every other
// observer residue strikes. Zero tokens — verdicts only.

import std/io
import std/bridge
import app/tau_wire

// No edge question asked yet — observer-aimed residue strikes like
// plain prose residue does.
app/tau_wire:residue-verdict(observer: true)
| observer |> std/io:print.ln("pre-edge observer residue -> observer")
| strike |> std/io:print.ln("pre-edge observer residue -> strike")

app/tau_wire:residue-verdict(observer: false)
| observer |> std/io:print.ln("pre-edge prose residue -> observer")
| strike |> std/io:print.ln("pre-edge prose residue -> strike")

// The edge question goes out at bound-2 — the next observer residue
// answers it free, the one after strikes.
app/tau_wire:bump-fail(n: 3, bound: 6)
| edge e |> std/io:print.ln("edge fired at n={{ e:d }}")
| retry r |> std/io:print.ln("unexpected retry {{ r:d }}")
| over |> std/io:print.ln("unexpected over")

app/tau_wire:residue-verdict(observer: true)
| observer |> std/io:print.ln("post-edge first observer residue -> observer")
| strike |> std/io:print.ln("post-edge first observer residue -> strike")

app/tau_wire:residue-verdict(observer: true)
| observer |> std/io:print.ln("second observer residue -> observer")
| strike |> std/io:print.ln("second observer residue -> strike")
