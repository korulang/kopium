// wrap-lines probe — paint a long line through viewport after reflow at
// width 20; the screen should show three rows, not one clipped line.
//
//   koruc probe_wrap.k && (sleep 1; printf 'x') | script -q /tmp/probe_wrap.out ./a.out
import std/io
import koru/vaxis

koru/vaxis:run(title: "probe")
| err e |> std/io:print.ln("probe failed: {{ e:s }}")

koru/vaxis(probe)
! draw w |> koru/vaxis:sub(parent: w, x: 0, y: 0, w: 0, h: 0): body
    |> koru/vaxis:wrap-lines(content: "aaa bbb ccc ddd eee fff ggg hhh iii jjj", width: 20): wl
    |> koru/vaxis:viewport(win: body, content: wl, offset: 0)
! key k |> koru/vaxis:quit()
