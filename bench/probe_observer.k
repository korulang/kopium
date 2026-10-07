// probe_observer.k — pins the bounded observer-residue exemption
// (task28 2026-10-05: 246 exempt observer residues until the 900s
// watchdog). One free observer answer per edge question; every other
// observer residue strikes. Zero tokens — verdicts only.

import std/io
import std/bridge
import app/tau_wire

// No edge question asked yet — observer-aimed residue strikes like
// plain prose residue does.
app/tau_wire:residue-verdict(observer: true, prose: "pre-edge observer prose")
| observer |> std/io:print.ln("pre-edge observer residue -> observer")
| deliver |> std/io:print.ln("pre-edge observer residue -> deliver")
| strike |> std/io:print.ln("pre-edge observer residue -> strike")

app/tau_wire:residue-verdict(observer: false, prose: "pre-edge prose")
| observer |> std/io:print.ln("pre-edge prose residue -> observer")
| deliver |> std/io:print.ln("pre-edge prose residue -> deliver")
| strike |> std/io:print.ln("pre-edge prose residue -> strike")

// A residue verdict carrying no prose — a mixed multi-item turn — has
// nothing to deliver and strikes unchanged.
app/tau_wire:residue-verdict(observer: false, prose: "")
| observer |> std/io:print.ln("unbound prose residue -> observer")
| deliver |> std/io:print.ln("unbound prose residue -> deliver")
| strike |> std/io:print.ln("unbound prose residue -> strike")

// The edge question goes out at bound-2 — the next observer residue
// answers it free, the one after strikes.
app/tau_wire:bump-fail(n: 3, bound: 6)
| edge e |> std/io:print.ln("edge fired at n={{ e:d }}")
| retry r |> std/io:print.ln("unexpected retry {{ r:d }}")
| over |> std/io:print.ln("unexpected over")

app/tau_wire:residue-verdict(observer: true, prose: "post-edge observer prose")
| observer |> std/io:print.ln("post-edge first observer residue -> observer")
| deliver |> std/io:print.ln("post-edge first observer residue -> deliver")
| strike |> std/io:print.ln("post-edge first observer residue -> strike")

app/tau_wire:residue-verdict(observer: true, prose: "second observer prose")
| observer |> std/io:print.ln("second observer residue -> observer")
| deliver |> std/io:print.ln("second observer residue -> deliver")
| strike |> std/io:print.ln("second observer residue -> strike")

// A reply that ran but moved neither n_say nor n_call delivered nothing.
app/tau_wire:mark-call-start()
|> app/tau_wire:delivered()
| said |> std/io:print.ln("empty reply -> said (unexpected)")
| silent |> std/io:print.ln("empty reply -> silent")
