# Hole 1 — `{{ }}` inside a child-tag attribute doesn't lift a component param

**Found:** 2026-07-31, building c_chat_pane.k's frame chrome.
**Confidence it's real:** ~85% (clean minimal repro; small chance the
attribute-interpolation spelling is simply different and undocumented).

A component's parameters are inferred from the `{{ name:fmt }}`
interpolations in its body — `topbar`'s `{{ title:s }}` gives it a `title`
input, and callers pass `title="…"` on the tag or `title:` at a call site.
That inference does NOT reach interpolations inside a CHILD TAG'S
ATTRIBUTE:

```koru
koru/vaxis:component(frame) {
    <dock>
        <statusbar dock="bottom" h="1" hint="{{ hint:s }}"/>
    </dock>
}
```

intends "frame takes `hint` and forwards it to statusbar". Instead frame's
emitted Input has no `hint` field, and a caller passing it gets:

    error: no field named 'hint' in struct '…frame_event.Input'

`input.k` here is the repro (koruc run input.k — fails today). c_chat_pane
bakes its hint static as the workaround-of-record.

**The want:** attribute interpolation lifts the name into the enclosing
component's params and forwards it — chrome components can't compose
dynamic state (a "streaming… / done" status line) without it.
