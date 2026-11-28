#!/usr/bin/env python3
"""Fat Chip 64 v0.66: an effect switched off keeps its settings for the
session: switched back on (C= + its key, or by editing one of its settings)
it comes back as it was, not at its defaults. And the BEATS page's GAME BOY
TREMOLO: OFF FOR BEATS (the default) holds the Game Boy's tremolo at depth 0
while it plays the beats (its tremolo is the whole Game Boy's volume, the
drums too); ALWAYS leaves it."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def mod(c, m, *keys, ms=40):
    c._raw_press(m, ms=30)
    for k in keys:
        c._raw_tap(k, ms=ms)
    c._raw_release(m, ms=60)


c = C64(channels=None)
c.fkeys_036 = False
c.keys_039 = False
c.run_ms(400)
check("header V0.69", "V0.69" in c.screen_row(0), c.screen_row(0))
S = c.sym


def field(name):
    return c.raw[S[name]]                     # (the live patch's fields have their own labels)


# ---------------------------------------------------------------- effects remember
c.midi_in(0xC0, 0, ms=200)                     # (FAT: no vibrato)
check("FAT: vibrato off", field("sndVib") == 0)
mod(c, "cbm", "v")
d0 = field("sndVib")
check("C= + V: on, at its default depth", d0 != 0, d0)
for _ in range(3):
    mod(c, "cbm", "crsrright")
c.run_ms(250)
d1 = (field("sndVib"), field("sndVibRL"), field("sndVibRH"), field("sndVibDel"))
check("C= + CRSR RIGHT x3: deeper", d1[0] != d0, (d0, d1))
mod(c, "cbm", "v")
c.run_ms(100)
check("C= + V: off", field("sndVib") == 0)
mod(c, "cbm", "v")
c.run_ms(100)
d2 = (field("sndVib"), field("sndVibRL"), field("sndVibRH"), field("sndVibDel"))
check("C= + V again: back as it was, not its defaults", d2 == d1, (d1, d2))
c.midi_in(0xC0, 1, ms=200)                     # (another patch: the setting follows the session)
c.midi_in(0xC0, 0, ms=200)
mod(c, "cbm", "v")
c.run_ms(100)
d3 = (field("sndVib"), field("sndVibRL"), field("sndVibRH"), field("sndVibDel"))
check("... after other patches too (this session)", d3 == d1, (d1, d3))
mod(c, "cbm", "c")                             # TREMOLO: never switched off this session
c.run_ms(100)
check("an effect not switched off yet: its defaults", field("nesTrem") != 0, field("nesTrem"))

# ---------------------------------------------------------------- GAME BOY TREMOLO
c2 = C64(channels=None)
c2.fkeys_036 = False
c2.keys_039 = False
c2.run_ms(400)
for _ in range(30):                            # TREMOLO GATE: tremolo on the Game Boy too
    if "TREMOLO GATE" in c2.screen_row(2):
        break
    c2._raw_tap(";", ms=80)
c2.run_ms(200)
check("TREMOLO GATE: tremolo on the Game Boy", "TREMOLO GATE" in c2.screen_row(2) and c2.v("tremChips") & 4 and c2.v("nesTrem"),
      (c2.screen_row(2), c2.v("tremChips"), c2.v("nesTrem")))
gb = c2.v("gbBase")


def trem(c, t0):
    return [b for t, s, a, b in c.midi(since=t0) if s == 0xB0 | gb and a == 115]


check("GAME BOY TREMOLO starts as OFF FOR BEATS", c2.v("gbBtTrem") == 0)
c2.set("beatDev", 1)
t0 = c2.cpu.processorCycles
c2._raw_tap("runstop", ms=40)
c2.run_ms(400)
check("the beats on the Game Boy: its tremolo depth goes to 0", trem(c2, t0)[-1:] == [0], trem(c2, t0))
t0 = c2.cpu.processorCycles
c2._raw_tap("runstop", ms=40)
c2.run_ms(400)
check("stopped: the patch's depth again", trem(c2, t0) and trem(c2, t0)[-1] > 0, trem(c2, t0))
c2.set("gbBtTrem", 1)
t0 = c2.cpu.processorCycles
c2._raw_tap("runstop", ms=40)
c2.run_ms(400)
check("ALWAYS: the beats leave it", 0 not in trem(c2, t0), trem(c2, t0))
c2._raw_tap("runstop", ms=40)
c2.set("gbBtTrem", 0)
c2.set("beatDev", 0)
t0 = c2.cpu.processorCycles
c2._raw_tap("runstop", ms=40)
c2.run_ms(400)
check("beats on the MidiNES only: the Game Boy's tremolo stays", 0 not in trem(c2, t0), trem(c2, t0))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
