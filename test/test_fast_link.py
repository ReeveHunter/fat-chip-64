#!/usr/bin/env python3
"""Fat Chip 64 v0.10: the fastest arp (10 ms, UNISON, 4-note chord) with a
SPACE bend on top: through the Teensyboy model, nothing is lost."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)
from teensy import forward  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


for pads in (False, True):
    c = C64()
    c.run_ms(150)
    if pads:
        c.tap("v", ms=40)
    c.tap("a", ms=30)
    for _ in range(4):
        c.tap(";", ms=30)
    c.tap(".", ms=30)                       # SPACE bends
    c.press("q", "e", "t", "u", ms=800)
    c.press("space", ms=1200)
    c.release("space", ms=700)
    c.release("q", "e", "t", "u", ms=600)
    out, lost = forward(c.tx)
    name = "PADS" if pads else "FAT"
    check(f"{name}: 10 ms arp + bend: no bytes lost in the Teensyboy", lost == 0, lost)
    on = {}
    st = None
    msgs = []
    for _, b in out:
        if b & 0x80:
            st, d = b, []
            continue
        d.append(b)
        if len(d) == 2:
            msgs.append((st, d[0], d[1]))
            d = []
    for s, a, b in msgs:
        if s & 0xF0 == 0x90 and b:
            on[s & 15] = a
        elif s & 0xF0 in (0x80, 0x90) and on.get(s & 15) == a:
            del on[s & 15]
    check(f"{name}: the Game Boy ends with nothing sounding", {k: v for k, v in on.items() if k < 3} == {}, on)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
