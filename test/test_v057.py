#!/usr/bin/env python3
"""Fat Chip 64 v0.57: TREMOLO held reaches the Game Boy (Fat Chip GB v0.13's
tremolo, CC 115-119): the patch's own tremolo (whatever its chips), or with
none the held tremolo's (DEEP, 6 HZ); let go, the patch's again."""
import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
P = gen_patches.PATCHES


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def trem(c, t0):
    gb = c.v("gbBase")
    return dict((a, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and (s & 15) == gb and 115 <= a <= 119)


def patch(c, tr=None, on=None):
    p = copy.deepcopy(P[2])                                  # RAW: no tremolo
    if tr:
        p["fx"]["tremolo"] = dict(tr, **({"on": on} if on else {}))
    c.midi_in(*gen_patches.sysex(p), ms=400)


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(500)
check("header V0.61", "V0.61" in c.screen_row(0), c.screen_row(0))
c.set("spaceAct", 4)                                         # SPACE: TREMOLO
patch(c)
t0 = c.cpu.processorCycles
c._raw_press("space", ms=200)
m = trem(c, t0)
check("a patch with no tremolo, SPACE (TREMOLO) held: the Game Boy gets the held tremolo (DEEP: 10 of 15, 6 Hz)",
      m.get(115) == 10 and m.get(117) == 0 and m.get(118, 0) * 128 + m.get(119, 0) in range(595, 606), m)
t0 = c.cpu.processorCycles
c._raw_release("space", ms=200)
check("let go: depth 0 again", trem(c, t0).get(115) == 0, trem(c, t0))

patch(c, {"depth": 60, "tremSync": 3, "shape": 6}, on=["sid", "nes"])   # PUMP 1/4, not on the Game Boy
t0 = c.cpu.processorCycles
c._raw_press("space", ms=200)
m = trem(c, t0)
check("a patch whose tremolo leaves the Game Boy out, held: its own tremolo there too (PUMP, 1/4)",
      m.get(115) == 9 and m.get(116) == 6 and m.get(117) == 3, m)
t0 = c.cpu.processorCycles
c._raw_release("space", ms=200)
check("let go: the patch's (off on the Game Boy)", trem(c, t0).get(115) == 0, trem(c, t0))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
