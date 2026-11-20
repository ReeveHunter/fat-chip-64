#!/usr/bin/env python3
"""Fat Chip 64 v0.53: One Key Play's notes get voices before the chord's, on
voices that aren't the bass, so the SPARKLE arp's pair doesn't squeeze them
out when fewer chips are on."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


BASS = (7, 8)
for devs, need in (((1, 1, 1), 2), ((1, 1, 0), 2), ((1, 0, 1), 2), ((0, 1, 1), 2), ((1, 0, 0), 1)):
    c = C64(channels=None)
    c.keys_039 = False
    c.fkeys_036 = False
    c.run_ms(400)
    for d, on in enumerate(devs):
        if not on:
            c._raw_press("ctrl", ms=20); c._raw_tap("asd"[d], ms=60); c._raw_release("ctrl", ms=60)
    c.set("okpOn", 1)
    c.set("playMode", 1)
    c.set("arpMode", 2)                                      # SPARKLE
    c.press("q", ms=300)
    c._raw_press("crsrdown", ms=50)
    worst, on_bass = 9, 0
    for _ in range(50):
        c.run_ms(10)
        vn = c.v("vNote", 9)
        o = [n for n in c.v("okpNotes", 2) if n != 255]
        worst = min(worst, sum(1 for n in o if n in vn))
        on_bass += sum(1 for v in BASS if c.v("vOkp", 9)[v])
    name = "+".join(n for n, on in zip(("SID", "GB", "NES"), devs) if on)
    check(f"SPARKLE, {name}: One Key Play's notes sound throughout ({need} of 2)", worst >= need, worst)
    check(f"... never on the bass voices", on_bass == 0, on_bass)
    c._raw_release("crsrdown", ms=50)
    c.release("q", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
