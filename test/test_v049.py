#!/usr/bin/env python3
"""Fat Chip 64 v0.49: a NES glide that lands exactly on its note (a whole
number of semitones, a late step) still sends the centred bend. Before, the
voice was left bent most of the way back to its last note (Reeve's NES LAG
NOTE patch: GLIDE on, TIME 0)."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
PATCH = {"name": "NES LAG NOTE", "fx": {"tone": {"sidWave": 4, "sidPw": 1396, "sidPwSpread": 0, "gbDuty1": 1, "gbDuty2": 1, "gbWaveMode": 0, "gbWaveShape": 6, "nesDuty1": 1, "nesDuty2": 0}, "env": {"attack": 68, "decay": 114, "sustain": 10, "release": 1500}, "filter": {"cutoff": 51, "resonance": 8, "envAmount": -48, "lfoDepth": 93, "filtLfoRate": 0.1}, "glide": {"time": 0}, "tremolo": {"depth": 57, "tremRate": 4.38, "tremSync": 4, "shape": 0}}, "octSid": 1, "octGb": 1, "lvlGbPulse": 15, "lvlGbWave": 15, "lvlNes": 10, "fatBass": 0}


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.55", "V0.55" in c.screen_row(0), c.screen_row(0))
c.midi_in(*gen_patches.sysex(PATCH), ms=300)
check("NES LAG NOTE: glide on (k 3)", c.v("glideK") == 3, c.v("glideK"))
nb = c.v("nesBase")
R = random.Random(1)
stuck = []
glides = 0
for i in range(30):
    k = R.choice("qwertyu")
    c.press(k, ms=R.choice([150, 400, 900]))
    c.release(k, ms=R.choice([100, 400, 1200]))
    last = {}
    for t, s, d1, d2 in c.midi():
        ch = (s & 15) - nb
        if 0 <= ch < 3 and s & 0xF0 == 0xE0:
            last[ch] = (d2 << 7 | d1) - 8192
            glides += abs(last[ch]) > 200
    stuck += [(i, k, ch, b) for ch, b in last.items() if abs(b) > 200]
check("it glides on the NES (big bends go out)", glides > 10, glides)
check("every NES voice ends up centred after its glide (no bend left over)", not stuck, stuck[:4])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
