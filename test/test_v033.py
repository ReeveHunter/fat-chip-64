#!/usr/bin/env python3
"""Fat Chip 64 v0.33: a patch's tremolo on the SID too (its master volume),
LFO / PUMP / GATE, for every tremolo patch by default; SID only or NES only
when the patch says so."""
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


def vols(c, n=80, ms=10):
    out = []
    for _ in range(n):
        c.run_ms(ms)
        out.append(c.raw[0xD418] & 15)
    return out


c = C64(channels=None)
c.run_ms(400)
check("header V0.33", "V0.33" in c.screen_row(0), c.screen_row(0))
check("no tremolo: the SID's volume steady at 15", set(vols(c, 20)) == {15})

# the built-in TREMOLO GATE patch: SID and NES by default
send(c, BY["TREMOLO GATE"])
check("TREMOLO GATE: tremChips = NES + SID", c.v("tremChips") == 3, c.v("tremChips"))
c.midi_in(0x90, 60, 100, ms=200)
v = vols(c)
check("... the SID's master volume chops on and off", min(v) <= 2 and max(v) == 15, v)
c.midi_in(0x80, 60, 0, ms=300)

# PUMP, synced: ducks and swells on the SID
send(c, 0, tremolo={"depth": 90, "tremSync": 3, "mode": 1})
c.midi_in(0x90, 60, 100, ms=100)
v = vols(c, 60)
rises = sum(1 for a, b in zip(v, v[1:]) if b < a - 5)
check("PUMP on the SID: a duck each beat, swelling back", max(v) >= 13 and min(v) <= 3 and rises in (1, 2), v)
c.midi_in(0x80, 60, 0, ms=300)

# NES only: the SID stays put
send(c, 0, tremolo={"depth": 100, "tremRate": 6, "on": ["nes"]})
check("tremolo on the NES only: tremChips 1", c.v("tremChips") == 1)
c.midi_in(0x90, 60, 100, ms=100)
check("... the SID's volume stays at 15", set(vols(c, 40)) == {15})
c.midi_in(0x80, 60, 0, ms=300)

# SID only: the NES's envelope isn't touched
send(c, 1, tremolo={"depth": 100, "tremRate": 6, "on": ["sid"]})
check("tremolo on the SID only: tremChips 2, and the NES doesn't follow", c.v("tremChips") == 2 and c.v("tremNes") == 0)
c.midi_in(0x90, 60, 100, ms=100)
v = vols(c, 40)
check("... the SID's volume moves", min(v) < 8, v)
c.midi_in(0x80, 60, 0, ms=300)

# another patch without tremolo: the volume back at 15
send(c, BY["RAW"])
check("a patch without tremolo: the SID back at full volume", set(vols(c, 20)) == {15})

# muted: the tremolo doesn't bring the SID back
send(c, BY["TREMOLO GATE"])
c.tap("/", ms=60)
check("muted (/): the SID's volume stays 0 under the tremolo", set(vols(c, 30)) == {0})
c.tap("/", ms=60)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
