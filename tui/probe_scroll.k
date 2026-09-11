// scroll granularity probe — is scroll.y denominated in visual rows?
// Window 20x6, content 9 short lines + one 79-char line (wraps to ~4 rows
// at w=20): 12 visual rows total, 6 visible. 'n' steps y +1, 'u' -1,
// 'q' quits. If wrap-aware, one 'n' slides the view exactly one ROW —
// mid-wrapped-line — not one logical line.
//
//   koruc probe_scroll.k && (sleep 1; printf 'nn'; sleep 1; printf 'q') | script -q /tmp/probe_scroll.out ./a.out
import std/io
import std/store
import koru/vaxis

std/store:new(scroll) { y: 0[i64] }

koru/vaxis:run(title: "probe")
| err e |> std/io:print.ln("probe failed: {{ e:s }}")

koru/vaxis(probe)
! draw w |> koru/vaxis:sub(parent: w, x: 0, y: 0, w: 20, h: 6): body
    |> koru/vaxis:wrap-lines(content: "L0\nL1\naaa bbb ccc ddd eee fff ggg hhh iii jjj kkk lll mmm nnn\nL3\nL4\nL5\nL6\nL7\nL8\nL9", width: 20): wl
    |> koru/vaxis:viewport(win: body, content: wl, offset: scroll.y)
! char k when k.ch == 'n' |> std/store:stored { scroll.y: scroll.y + 1 }
! char k when k.ch == 'u' and scroll.y > 0 |> std/store:stored { scroll.y: scroll.y - 1 }
! up _ when scroll.y > 0 |> std/store:stored { scroll.y: scroll.y - 1 }
! down _ |> std/store:stored { scroll.y: scroll.y + 1 }
! wheel-up _ when scroll.y > 0 |> std/store:stored { scroll.y: scroll.y - 1 }
! wheel-down _ |> std/store:stored { scroll.y: scroll.y + 1 }
! char k when k.ch == 'q' |> koru/vaxis:quit()
