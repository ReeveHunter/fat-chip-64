#!/usr/bin/env python3
"""Fat Chip 64 v0.39: the SID's filter cutoff stays where a 6581 can be heard
($28-$EF, for the patch, its envelope / LFO / key track, FILTER SWEEP and the
DH-100's breath); the dice roll the envelope and the newer effects too."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
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


def cutoffs(c, ms):
    seen = set()
    for _ in range(ms // 5):
        c.run_ms(5)
        seen.add(c.raw[0xD416])
    return seen


c = C64(channels=None)
c.run_ms(400)
check("header V0.64", "V0.64" in c.screen_row(0), c.screen_row(0))

for cut, want in ((1, 0x29), (128, 0x28 + 100), (255, 0xEF)):           # (0: no filter)
    send(c, BY["RAW"], filter={"cutoff": cut, "resonance": 8})
    c.midi_in(0x90, 60, 100, ms=60)
    check(f"filter CUTOFF {cut}: the SID's register {hex(want)}", c.raw[0xD416] == want, hex(c.raw[0xD416]))
    c.midi_in(0x80, 60, 0, ms=200)

# a deep LFO and a falling envelope: never into the shut part
send(c, BY["RAW"], filter={"cutoff": 30, "resonance": 10, "lfoDepth": 127, "filtLfoRate": 8, "envAmount": -60, "envDecay": 200})
c.midi_in(0x90, 60, 100, ms=10)
seen = cutoffs(c, 800)
check("filter LFO + envelope: the cutoff moves, never below $28 or above $EF", len(seen) > 5 and min(seen) >= 0x28
      and max(seen) <= 0xEF, (hex(min(seen)), hex(max(seen)), len(seen)))
c.midi_in(0x80, 60, 0, ms=200)

# FILTER SWEEP on an unfiltered patch: closes down, but not shut
send(c, BY["RAW"])
c.set("sweepLvl", 255)
c.midi_in(0x90, 60, 100, ms=10)
seen = cutoffs(c, 300)
check("FILTER SWEEP: it closes down but never below the window ($28)", min(seen) >= 0x28 and min(seen) < 0x60, sorted(hex(x) for x in seen)[:5])
c.set("sweepLvl", 0)
c.midi_in(0x80, 60, 0, ms=300)

# the dice: the envelope rolls too, and the newer effects come up
send(c, BY["FAT"])
envs, fx = set(), set()
for i in range(80):
    c._raw_press("lshift", ms=10)
    c._raw_tap("/", ms=40)
    c._raw_release("lshift", ms=30)
    lp = c.v("livePatch", 128)
    envs.add((c.v("sndAD"), c.v("sndSR")))
    for name in ("sndStep", "sndClick", "sndPenv", "sndRdrop"):      # (v0.41: ATTACK is BEND IN STEP / CLICK)
        if c.v(name):
            fx.add(name)
check("SHIFT + /: the envelope (attack / decay / sustain / release) changes from roll to roll", len(envs) >= 20, len(envs))
check("... and ATTACK / BEND IN / BEND OUT turn up sometimes", len(fx) >= 2, fx)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
