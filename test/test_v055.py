#!/usr/bin/env python3
"""Fat Chip 64 v0.55 (Fat Chip GB v0.13): the patch's TREMOLO on the Game Boy
(its master volume, done there, locked to the tempo): CC 115 depth, 116 shape,
117 sync, 118 / 119 the FREE rate (Hz x 100), each only when it changes. End
to end: the Game Boy ROM's volume swings."""
import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim import C64, CYCLES_PER_MS  # noqa: E402
from teensy import forward  # noqa: E402
import gen_patches  # noqa: E402

GB_REPO = os.environ.get("FATCHIP_GB", os.path.join(HERE, "..", "..", "fat-chip-gb"))
sys.path.insert(0, os.path.join(GB_REPO, "test"))
from harness import GB  # noqa: E402

fails = 0
P = gen_patches.PATCHES


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def send(c, trem, on=None):
    p = copy.deepcopy(P[2])                                  # RAW
    if trem:
        p["fx"]["tremolo"] = dict(trem, **({"on": on} if on else {}))
    t0 = c.cpu.processorCycles
    c.midi_in(*gen_patches.sysex(p), ms=400)
    gb = c.v("gbBase")
    return [(a, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and (s & 15) == gb and 115 <= a <= 119]


c = C64(channels=None)
c.run_ms(500)
check("header V0.64", "V0.64" in c.screen_row(0), c.screen_row(0))
m = send(c, {"depth": 100, "tremRate": 2, "shape": 0})
check("TREMOLO 100 %, 2 Hz, TRI: depth 15, TRI, FREE, rate 200 (1 x 128 + 72)",
      dict(m) == {115: 15, 116: 0, 117: 0, 118: 1, 119: 72} or (dict(m).get(115) == 15 and dict(m).get(118) == 1 and abs(dict(m).get(119, 0) - 72) <= 1), m)
m = send(c, {"depth": 100, "tremRate": 2, "shape": 0})
check("the same again: nothing re-sent", m == [], m)
m = send(c, {"depth": 100, "tremSync": 3, "shape": 6})
check("PUMP, SYNC 1/4: shape 6, sync 3", dict(m).get(116) == 6 and dict(m).get(117) == 3, m)
m = send(c, {"depth": 100, "tremSync": 1, "shape": 8})
check("GATE XX.XX.X., SYNC 1 BAR: shape 8, sync 1", dict(m).get(116) == 8 and dict(m).get(117) == 1, m)
m = send(c, {"depth": 100, "tremRate": 2, "shape": 0}, on=["sid", "nes"])
check("tremolo not on the Game Boy: depth 0", dict(m).get(115) == 0, m)
m = send(c, None)
check("no tremolo: depth stays 0 (nothing sent)", m == [], m)

# ---------------------------------------------------------------- end to end
c = C64(channels=None)
c.run_ms(500)
send(c, {"depth": 100, "tremRate": 2, "shape": 0})
c.midi_in(0x90, 60, 100, ms=1500)
wire, lost = forward(list(c.tx))
gb = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
gb.run(120)
FRAME = CYCLES_PER_MS * 1000 / 59.7275
t0 = wire[0][0]
i, frame, vol = 0, 0, []
while i < len(wire) or frame < 60:
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        i += 1
    if chunk:
        gb.midi(*chunk)
    gb.run(1)
    vol.append(gb.mem(0xFF24) & 7)
    frame += 1
for _ in range(120):                         # (2 s more)
    gb.run(1)
    vol.append(gb.mem(0xFF24) & 7)
tail = vol[-90:]
check("end to end: the Game Boy's master volume swings with the tremolo", min(tail) == 0 and max(tail) == 7, (min(tail), max(tail)))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
