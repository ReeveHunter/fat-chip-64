#!/usr/bin/env python3
"""Fat Chip 64 v0.20: a whole patch over MIDI (SysEx from Chip Lab) goes into
the live patch and sounds at once."""
import copy
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)
import gen_patches  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


P = gen_patches.PATCHES
size = json.load(open(os.path.join(os.path.dirname(__file__), "..", "patch", "c64-layout.json")))["patchSize"]
c = C64(channels=None)
c.run_ms(400)
check("header V0.26", "V0.26" in c.screen_row(0), c.screen_row(0))

# a built-in patch sent whole matches what choosing it loads
for i in (1, 13):
    c.midi_in(*gen_patches.sysex(P[i]), ms=200)
    sent = c.v("livePatch", size)
    c.midi_in(0xC0, 0, ms=200)
    c.midi_in(0xC0, i, ms=200)
    check(f"{P[i]['name']}: the SysEx bytes are the built-in patch's", sent == c.v("livePatch", size))

# a new patch: PADS, brighter, with a name of its own
p = copy.deepcopy(P[1])
p["name"] = "Chip Lab Test"
p["fx"]["filter"]["cutoff"] = 200
p["fx"]["filter"]["lfoDepth"] = 0
c.midi_in(0xC0, 0, ms=200)
n0 = c.v("sxCount")
c.midi_in(*gen_patches.sysex(p), ms=200)
check("received: counted, in the live patch", c.v("sxCount") == n0 + 1 and c.v("livePatch", size) == gen_patches.patch_bytes(p))
check("its name on screen", "CHIP LAB TEST" in c.screen_row(2), c.screen_row(2))
c.press("q", ms=200)
check("it sounds at once: filter cutoff 200", c.raw[0xD416] == 200 and c.raw[0xD405] == 0xA0, (c.raw[0xD416], hex(c.raw[0xD405])))
c.release("q", ms=100)

# broken ones are ignored
good = gen_patches.sysex(p)
q = copy.deepcopy(p); q["fx"]["filter"]["cutoff"] = 40
bad = gen_patches.sysex(q)
for name, msg in (("a wrong header", [0xF0, 0x7D, 0x46, 0x44] + bad[4:]),
                  ("a short one", bad[:-3] + [0xF7]),
                  ("one cut by a note", bad[:60] + [0x90, 60, 100] + bad[60:]),
                  ("another patch size", bad[:5] + [size + 1] + bad[6:] + [0, 0])):
    n0 = c.v("sxCount")
    c.midi_in(*msg, ms=150)
    check(f"{name}: ignored", c.v("sxCount") == n0 and c.v("sndCut") == 200, c.v("sndCut"))
c.midi_in(0x80, 60, 0, ms=100)

# a built-in patch again: V and program changes still work after one
c.midi_in(0xC0, 1, ms=200)
check("then a program change loads PADS again", c.v("soundMode") == 1 and c.v("sndCut") == 0x10 and "PADS" in c.screen_row(2))
c.midi_in(*good, ms=200)
c._raw_tap("z", ms=100)
c._raw_tap("a", ms=200)
check("v0.22: Z (and A) after a received patch: the bank's patch, FAT", c.v("soundMode") == 0 and "FAT" in c.screen_row(2), c.screen_row(2))
c.midi_in(*good, ms=200)
c.midi_in(0xC0, 1, ms=200)
check("a program change to the number it had before still loads (PADS)", c.v("soundMode") == 1 and c.v("sndCut") == 0x10)

# while a chord is held: the new patch takes over, the notes keep sounding
c.press("q", "e", "t", ms=200)
c.midi_in(*good, ms=300)
check("chord held: the new patch sounds on it (cutoff 200, still gated)", c.raw[0xD416] == 200 and c.raw[0xD404] & 1, c.raw[0xD416])
c.release("q", "e", "t", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
