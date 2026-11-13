#!/usr/bin/env python3
"""End to end, v0.12: Fat Chip 64 with its own channels (Game Boy 11-15,
MidiNES 1-5) -> Teensyboy model -> Fat Chip GB v0.08 (PyBoy), which starts on
its default 1-5. CC 113 moves it to 11-15, then a chord and a MONO legato
change play; MidiNES traffic on 1-5 doesn't reach any Game Boy voice."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)
from teensy import forward  # noqa: E402

GB_REPO = os.environ.get("FATCHIP_GB", os.path.join(HERE, "..", "..", "fat-chip-gb"))
sys.path.insert(0, os.path.join(GB_REPO, "test"))
from harness import GB  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


c = C64(channels=None)
c.run_ms(400)
c.press("q", "e", "t", ms=150)          # C3 E3 G3
t_chord = c.cpu.processorCycles
c.run_ms(200)
c.release("q", "e", "t", ms=300)
c.tap("c", ms=200)                      # MONO
c.press("q", ms=150)
c.press("t", ms=150)                    # legato to G3
t_leg = c.cpu.processorCycles
c.run_ms(100)
c.release("t", "q", ms=300)
c.midi_in(0x9F, 45, 127, 0x9F, 57, 64, ms=100)   # keytar drums: MidiNES only
wire, lost = forward(list(c.tx))
check("Teensyboy model: nothing lost", lost == 0, lost)

gb = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
gb.run(120)
check("Fat Chip GB starts on 1-5", gb.var("_midi_ch", 5) == [0, 1, 2, 3, 4])
FRAME = CYCLES_PER_MS * 1000 / 59.7275
t0 = wire[0][0]
i = frame = 0
snap = {}
vs = gb.sym["_voice"]
while i < len(wire):
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        i += 1
    if chunk:
        gb.midi(*chunk)
    gb.run(1)
    frame += 1
    if "chord" not in snap and limit >= t_chord + 60 * CYCLES_PER_MS:
        snap["chord"] = ([gb.mem(vs + v * 48) for v in range(3)], gb.mem(0xFF26))
    if "leg" not in snap and limit >= t_leg + 60 * CYCLES_PER_MS:
        snap["leg"] = [gb.mem(vs + v * 48) for v in range(3)]
gb.run(30)
check("CC 113 moved it to 11-15", gb.var("_midi_ch", 5) == [10, 11, 12, 13, 14], gb.var("_midi_ch", 5))
notes, nr52 = snap["chord"]
check("the chord plays on the Game Boy (pulses C3 / E3 or G3, wave the Fat Bass C2)",
      notes[0] in (48, 52, 55) and notes[1] in (48, 52, 55) and notes[2] == 36 and nr52 & 3 == 3, (notes, hex(nr52)))
check("MONO legato: the Game Boy moved to G3", snap["leg"][:2] == [55, 55], snap["leg"])
gb.stop()
print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
