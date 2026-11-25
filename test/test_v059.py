#!/usr/bin/env python3
"""Fat Chip 64 v0.59 (Fat Chip GB v0.16): BEND IN up to 4 octaves (AMOUNT
-48 ... +48). The SID starts that far away (kept within its notes, no
wrapping round); the Game Boy gets half the AMOUNT and BEND SHAPE's x2 bit
(bit 3); the NES bends at most 2 octaves, as before."""
import copy
import math
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


def send(c, **penv):
    p = copy.deepcopy(P[2])
    p["fx"]["penv"] = penv
    t0 = c.cpu.processorCycles
    c.midi_in(*gen_patches.sysex(p), ms=400)
    gb = c.v("gbBase")
    return {a: b for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and (s & 15) == gb}


def sid_note(c, v=0):
    f = c.raw[0xD400 + 7 * v] | c.raw[0xD401 + 7 * v] << 8
    lo = c.sym["sidFreqLo"]
    tbl = [c.raw[lo + i] | c.raw[c.sym["sidFreqHi"] + i] << 8 for i in range(128)]
    return min(range(128), key=lambda i: abs(tbl[i] - f)) if f else None


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(500)
check("header V0.65", "V0.65" in c.screen_row(0), c.screen_row(0))
m = send(c, amount=36, time=300, shape=1)
check("STEP +36: the Game Boy gets +18 (CC 80) and BEND SHAPE STEP + x2 (9)", m.get(80) == gen_patches.cc(18 + 24, 48) and m.get(89) == 9, (m.get(80), m.get(89)))
c.set("monoMode", 1)
c.midi_in(0x90, 48, 100, ms=60)
check("... the SID holds three octaves up (84)", sid_note(c) == 84, sid_note(c))
c.midi_in(0x80, 48, 0, ms=400)
c.midi_in(0x90, 96, 100, ms=60)
f = c.raw[0xD400] | c.raw[0xD401] << 8
top = c.raw[c.sym["sidFreqLo"] + 115] | c.raw[c.sym["sidFreqHi"] + 115] << 8
check("... from a high note (96): kept at the top (note 115: the SID's highest), not wrapped round to the bottom", f == top and f > 30000, (f, top))
c.midi_in(0x80, 96, 0, ms=400)
m = send(c, amount=-48, time=300, shape=1)
check("STEP -48: the Game Boy gets -24 and x2", m.get(80) == 0 and m.get(89) == 9, (m.get(80), m.get(89)))
c.midi_in(0x90, 60, 100, ms=60)
check("... the SID from four octaves down (12)", sid_note(c) == 12, sid_note(c))
c.midi_in(0x80, 60, 0, ms=400)
c.midi_in(0x90, 30, 100, ms=60)
check("... from a low note (30): kept at the bottom (0)", sid_note(c) == 0, sid_note(c))
c.midi_in(0x80, 30, 0, ms=400)
m = send(c, amount=12, time=80, shape=1, click=1)
check("+12 (in 2 octaves): no x2 (STEP + CLICK: 3)", m.get(89) == 3, m.get(89))
nb = c.v("nesBase")
send(c, amount=48, time=300, shape=1)
t0 = c.cpu.processorCycles
c.midi_in(0x90, 48, 100, ms=60)
b = [(s & 15, (d2 << 7 | d1) - 8192) for t, s, d1, d2 in c.midi() if t >= t0 and s & 0xF0 == 0xE0 and (s & 15) == nb]
p = 3420 * 0.5 ** ((48 - 36) / 12)
want = p * (2 - 2 * 0.5 ** 2)                                  # two octaves up at note 48
check("the NES: at most two octaves (its bend for +24 at note 48), no wrap", b and abs(b[0][1] - want) < want * 0.05, (b[:2], round(want)))
c.midi_in(0x80, 48, 0, ms=400)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
