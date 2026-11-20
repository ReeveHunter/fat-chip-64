#!/usr/bin/env python3
"""Fat Chip 64 v0.48: with SUSTAIN 0 the NES triangle (no volume of its own)
stops when the pulses' envelope has decayed to silence, instead of sounding
as long as the key is held."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
CPS = 985248
DEMO = json.load(open(os.path.join(os.path.dirname(__file__), "..", "patch", "demo-patches.json")))["patches"]


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def nes(c, t0, ch):
    nb = c.v("nesBase")
    return [((t - t0) * 1000 // CPS, s & 0xF0, a, b) for t, s, a, b in c.midi()
            if t >= t0 and (s & 15) == nb + ch and s & 0xF0 in (0x80, 0x90, 0xB0)]


def last_vol(ev):
    v = [b for _, s, a, b in ev if s == 0xB0 and a == 7]
    return v[-1] if v else None


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.49", "V0.49" in c.screen_row(0), c.screen_row(0))
clav = next(p for p in DEMO if p["name"] == "CLAV")
c.midi_in(*gen_patches.sysex(clav), ms=300)
c.set("playMode", 0)
c.set("monoMode", 0)

t0 = c.cpu.processorCycles
c.press("q", ms=1500)
tri = [(t, s, a) for t, s, a, b in nes(c, t0, 2) if s in (0x80, 0x90)]
p1 = nes(c, t0, 0)
zero = next((t for t, s, a, b in p1 if s == 0xB0 and a == 7 and b == 0), None)
check("CLAV (SUSTAIN 0), a key held: the triangle starts", tri and tri[0][1] == 0x90, tri)
off = [t for t, s, a in tri if s == 0x80]
check("... and stops when the pulses have faded (about 170 ms), not at the key's release",
      len(off) == 1 and zero is not None and abs(off[0] - zero) <= 30, (off, zero))
t1 = c.cpu.processorCycles
c.release("q", ms=600)
check("let go: no second note-off for it", not [e for e in nes(c, t1, 2) if e[1] in (0x80, 0x90)], nes(c, t1, 2))

# latch, chord changes: each new chord's triangle plays and stops again
c._raw_tap("l", ms=60)
c.set("playMode", 1)
for k, root in (("q", 36), ("t", 31)):
    t0 = c.cpu.processorCycles
    c.press(k, ms=100)
    c.release(k, ms=900)
    tri = [(s, a) for t, s, a, b in nes(c, t0, 2) if s in (0x80, 0x90)]
    check(f"latched {k.upper()}: its triangle note, then its stop", tri[-2:] == [(0x90, root), (0x80, root)], tri)
c._raw_tap("l", ms=60)
c.run_ms(400)

# a sound with sustain: the triangle sounds while held, as before
pad = next(p for p in DEMO if p["fx"].get("env", {}).get("sustain", 0) > 0)
c.midi_in(*gen_patches.sysex(pad), ms=300)
c.set("playMode", 0)
t0 = c.cpu.processorCycles
c.press("q", ms=1500)
tri = [s for t, s, a, b in nes(c, t0, 2) if s in (0x80, 0x90)]
check(f"{pad['name']} (SUSTAIN {pad['fx']['env']['sustain']}): the triangle holds while the key does", tri == [0x90], tri)
c.release("q", ms=600)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
