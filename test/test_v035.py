#!/usr/bin/env python3
"""Fat Chip 64 v0.35: TREMOLO's PUMP ducks like a compressor to a kick: all
the way down for the first tenth of the cycle, then a curved swell (quick,
easing in), at full volume from half way. SAW UP stays an even ramp."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def cycle(c, **trem):
    p = copy.deepcopy(gen_patches.PATCHES[0])
    p["fx"]["tremolo"] = trem
    c.midi_in(*gen_patches.sysex(p), ms=250)
    c.midi_in(0x90, 60, 100, ms=100)
    a = []
    for _ in range(150):
        c.run_ms(10)
        a.append(c.v("tremA"))
    c.midi_in(0x80, 60, 0, ms=300)
    s = next(i for i in range(1, len(a)) if a[i] > a[i - 1] + 6)       # a cycle's start
    e = next(i for i in range(s + 1, len(a)) if a[i] > a[i - 1] + 6)
    return a[s:e]


c = C64(channels=None)
c.run_ms(400)
check("header V0.35", "V0.35" in c.screen_row(0), c.screen_row(0))
p = cycle(c, depth=100, tremSync=3, mode=1)                 # PUMP, 1/4 (500 ms at 120)
n = len(p)
held = sum(1 for x in p[:n // 5] if x == p[0])
zero_at = next(i for i, x in enumerate(p) if x == 0)
early = p[held] - p[held + 6]
late = p[zero_at - 7] - p[zero_at - 1]
check("PUMP: all the way down for about the first tenth", p[0] >= 13 and 3 <= held <= 7, p[:12])
check("... a swell back, quicker at first than at the end", early > late, (early, late, p))
check("... at full volume (no cut) from about half way", 0.35 * n <= zero_at <= 0.55 * n and all(x == 0 for x in p[zero_at:]),
      (zero_at, n))
s = cycle(c, depth=100, tremSync=3, shape=2)                # SAW UP
steps = [x - y for x, y in zip(s, s[1:])]
check("SAW UP: an even ramp over the whole cycle", s[0] >= 13 and s[-1] <= 1 and all(0 <= d <= 1 for d in steps), s)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
