// Repro for HOLE.md — `{{ hint:s }}` in a child-tag attribute should lift
// `hint` into frame's params; instead the caller's `hint:` arg is refused:
//   error: no field named 'hint' in struct '…frame_event.Input'
//
//   koruc run input.k   (from this directory; fails today)

import std/io
import koru/vaxis

koru/vaxis:component(statusbar) {
    <text>{{ hint:s }}</text>
}

koru/vaxis:component(frame) {
    <dock>
        <statusbar dock="bottom" h="1" hint="{{ hint:s }}"/>
    </dock>
}

koru/vaxis:run(title: "hole1")
| err e |> std/io:print.ln("hole1: {{ e:s }}")

koru/vaxis(hole1)
! draw w |> frame(win: w, hint: "lifted?")
! key k when k.ch == 'q' |> koru/vaxis:quit()
