#!/usr/bin/env python3
"""Fat Chip 64 v0.34: the SID's volume never jumps (a step every 2 ms towards
where it's going: no thump on a 6581); the tremolo holds still while nothing
sounds on the SID; every tremolo SHAPE plays; SHAPE can be changed in the menu
(TRI and SINE no longer stick it; PWM's when it has the LFO)."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64, CYCLES_PER_MS  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
P = gen_patches.PATCHES
BY = {p["name"]: i for i, p in enumerate(P)}


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def send(c, base, **fx):
    p = copy.deepcopy(P[base])
    p["fx"].update(fx)
    n0 = c.v("sxCount")
    c.midi_in(*gen_patches.sysex(p), ms=250)
    assert c.v("sxCount") == (n0 + 1) & 255, "SysEx not taken"


def vol_writes(c, ms):
    """every write to $D418 for ms milliseconds: [(ms, volume)]"""
    out, t0 = [], c.cpu.processorCycles
    last = c.raw[0xD418] & 15
    end = t0 + ms * CYCLES_PER_MS
    while c.cpu.processorCycles < end:
        c.step()
        v = c.raw[0xD418] & 15
        if v != last:
            out.append(((c.cpu.processorCycles - t0) / CYCLES_PER_MS, v))
            last = v
    return out


def rows(c):
    return [c.screen_row(r) for r in range(25)]


def sel(c, label):
    for _ in range(40):
        if any(r.startswith("> " + label) for r in rows(c)):
            return True
        c.tap("crsrdown", ms=25)
    return False


c = C64(channels=None)
c.run_ms(400)
check("header V0.37", "V0.37" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- no jumps
send(c, BY["TREMOLO GATE"])
c.midi_in(0x90, 60, 100, ms=50)
w = vol_writes(c, 600)
vals = [15] + [v for _, v in w]
steps = [abs(b - a) for a, b in zip(vals, vals[1:])]
gaps = [b[0] - a[0] for a, b in zip(w, w[1:])]
check("TREMOLO GATE on the SID: the volume moves one step at a time", steps and max(steps) == 1, steps[:20])
check("... no faster than a step every 2 ms", min(gaps) >= 1.9, round(min(gaps), 2))
check("... and still chops right down and back up", min(vals) == 0 and vals.count(15) > 1, vals[:40])
c.midi_in(0x80, 60, 0, ms=10)

# ---------------------------------------------------------------- the silence: still
c.run_ms(800)                                # (TREMOLO GATE's release: 240 ms)
w = vol_writes(c, 500)
w = [x for x in w if x[0] > 40]             # (the last steps up to full as the release ends)
check("nothing sounding on the SID: no volume changes at all", w == [] and c.raw[0xD418] & 15 == 15, w[:10])
c.midi_in(0x90, 60, 100, ms=10)
w = vol_writes(c, 300)
check("a note: the tremolo again", len(w) > 10, len(w))
c.midi_in(0x80, 60, 0, ms=10)
w = vol_writes(c, 120)
check("... let go: it goes on while the release rings", len(w) > 3, len(w))
c.run_ms(800)

# ---------------------------------------------------------------- mute: a quick fade, not a pop
c.midi_in(0x90, 60, 100, ms=50)
send(c, BY["RAW"])
c.run_ms(100)
c._raw_press("/", ms=1)
w = vol_writes(c, 100)
c._raw_release("/", ms=30)
check("mute: the SID fades out in steps (about 30 ms)", [v for _, v in w] == list(range(14, -1, -1)) and 25 < w[-1][0] - w[0][0] < 35,
      w[:16])
c.tap("/", ms=60)
c.midi_in(0x80, 60, 0, ms=100)

# ---------------------------------------------------------------- the shapes
def amounts(c, n=120):
    out = []
    for _ in range(n):
        c.run_ms(10)
        out.append(c.v("tremA"))
    return out


for shape, name in ((2, "SAW UP"), (3, "SAW DOWN"), (5, "RANDOM"), (1, "SINE")):
    send(c, BY["RAW"], tremolo={"depth": 100, "tremRate": 2, "shape": shape})
    c.midi_in(0x90, 60, 100, ms=50)
    a = amounts(c)
    c.midi_in(0x80, 60, 0, ms=50)
    if shape == 2:
        falls = sum(1 for x, y in zip(a, a[1:]) if y < x)
        jumps = sum(1 for x, y in zip(a, a[1:]) if y > x)
        check("SAW UP: the cut shrinks step by step (the volume rises), then jumps back", falls > 30 and 1 <= jumps <= 3, a[:30])
    elif shape == 3:
        rises = sum(1 for x, y in zip(a, a[1:]) if y > x)
        drops = sum(1 for x, y in zip(a, a[1:]) if y < x)
        check("SAW DOWN: the cut grows step by step, then jumps back", rises > 30 and 1 <= drops <= 3, a[:30])
    elif shape == 5:
        check("RANDOM: a level held for each cycle, changing between them", len(set(a)) >= 2 and
              sum(1 for x, y in zip(a, a[1:]) if x != y) <= 4, a)
    else:
        check("SINE: smooth, the whole range", min(a) == 0 and max(a) >= 14, a[:50])

# ---------------------------------------------------------------- SHAPE in the menu
c.tap("return", ms=80)
sel(c, "PATCH")
c.tap("return", ms=80)
seen = {}
for fx in ("PWM", "VIBRATO", "TREMOLO"):
    sel(c, fx)
    c.tap("f7", ms=60)
    c.tap("return", ms=80)
    sel(c, "SHAPE")
    got = []
    for _ in range(6):
        c.tap("f7", ms=60)
        got.append(next(r for r in rows(c) if "SHAPE" in r).split()[-1])
    seen[fx] = got
    c._raw_press("lshift", ms=8); c._raw_tap("return", ms=60); c._raw_release("lshift", ms=60)
check("PWM's SHAPE steps (it has the LFO)", len(set(seen["PWM"])) >= 4, seen["PWM"])
check("VIBRATO's SHAPE steps (SINE plays as TRI on the Game Boy, so it's left out)", len(set(seen["VIBRATO"])) >= 4
      and "SINE" not in seen["VIBRATO"], seen["VIBRATO"])
check("TREMOLO's SHAPE: all six", len(set(seen["TREMOLO"])) == 6, seen["TREMOLO"])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
