#!/usr/bin/env python3
"""Fat Chip 64 v0.47: F7 steps MONO -> POLY -> SMART CHORD -> MONO (DRONE ->
POLY)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


NAME = {(0, 1): "MONO", (0, 0): "POLY", (1, 0): "SMART CHORD", (2, 0): "DRONE"}
c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.68", "V0.68" in c.screen_row(0), c.screen_row(0))
c.set("playMode", 0)
c.set("monoMode", 1)
seen = []
for _ in range(4):
    c._raw_tap("f7", ms=60)
    seen.append(NAME.get((c.v("playMode"), c.v("monoMode")), "?"))
check("F7 from MONO: POLY, SMART CHORD, MONO, POLY", seen == ["POLY", "SMART CHORD", "MONO", "POLY"], seen)
c.set("playMode", 2)
c.set("monoMode", 0)
c._raw_tap("f7", ms=60)
check("F7 from DRONE: POLY", NAME.get((c.v("playMode"), c.v("monoMode"))) == "POLY", (c.v("playMode"), c.v("monoMode")))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
