// Hole 8 driver — create a bridge on the colliding scope. Compiling this
// is the whole repro: the generated dispatch_collide's local `name_len`
// shadows the module's `var name_len` at backend build.
import std/io
import std/bridge
import app/repro

[with]std/bridge:create(id: "repro", scope: "collide"): br
|> std/io:print.ln("registered — dispatch_collide compiled")
