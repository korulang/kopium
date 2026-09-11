// paste assembly probe — ! paste turns the CSI 200/201 keystroke burst
// into one string. Binding the arm is what turns bracketed paste on.
//
//   koruc probe_paste.k && (sleep 1; printf '\x1b[200~hello pasted world\x1b[201~'; sleep 1; printf 'q') | script -q /tmp/probe_paste.out ./a.out
//   then: grep 'PASTE\[' /tmp/probe_paste.out
import std/io
import koru/vaxis

koru/vaxis:run(title: "paste-probe")
| err e |> std/io:print.ln("probe failed: {{ e:s }}")

koru/vaxis(paste-probe)
! paste t |> std/io:print.ln("PASTE[{{ t:s }}]")
! char k when k.ch == 'q' |> koru/vaxis:quit()
! escape _ |> koru/vaxis:quit()
