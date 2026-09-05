// Repro for HOLE.md — CLOSED 2026-09-05 (see verdict at the bottom of HOLE.md).
//
// `hint={{ hint:s }}` (BARE braces) in a child-tag attribute lifts `hint`
// into frame's params and forwards it to statusbar. This builds clean and
// the `frame(win: w, hint: "lifted?")` call typechecks.
//
// Spelling note: QUOTES mean literal. `hint="{{ hint:s }}"` passes the
// literal string through — no lift, and the caller's `hint:` arg is refused
// (quotes = literal, bare braces = forward). Interpolation inside quoted
// attr strings would be a new feature (fmt rail for attrs), unfiled.
//
//   koruc build input.k   (from this directory; green since e262a87)

import std/io
import koru/vaxis

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(frame) {
    <dock>
        <statusbar dock="bottom" h="1" hint={{ hint:s }}/>
    </dock>
}

koru/vaxis:run(title: "hole1")
| err e |> std/io:print.ln("hole1: {{ e:s }}")

koru/vaxis(hole1)
! draw w |> frame(win: w, hint: "lifted?")
! key k when k.ch == 'q' |> koru/vaxis:quit()
