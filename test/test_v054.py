#!/usr/bin/env python3
"""Fat Chip 64 v0.54 (Fat Chip GB v0.12): BEND IN's SHAPE and CLICK on the
Game Boy. CC 89 (BEND SHAPE) = STEP (bit 0, with an AMOUNT) + CLICK x 2 on
pulse 1, pulse 2 and the wave; for STEP (and a LONG CLICK) CC 81 is the hold
time, Fat Chip GB's step frames. End to end: the Game Boy ROM holds the
blip and jumps."""
import copy
import math
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


def send(c, **penv):
    p = copy.deepcopy(P[2])                                  # RAW: plain
    p["fx"]["penv"] = penv
    t0 = c.cpu.processorCycles
    c.midi_in(*gen_patches.sysex(p), ms=400)
    gb = c.v("gbBase")
    return {(s & 15) - gb: {} for s in range(1)} if False else {
        ch: {a: b for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and (s & 15) == gb + ch} for ch in range(3)}


c = C64(channels=None)
c.run_ms(500)
check("header V0.58", "V0.58" in c.screen_row(0), c.screen_row(0))
gbm = [(a, b) for t, s, a, b in c.midi() if s & 0xF0 == 0xB0 and c.v("gbBase") <= (s & 15) < c.v("gbBase") + 3]
check("the Game Boy's startup (now over 64 messages) arrives whole: it waits for room, ends with the status",
      len(gbm) > 64 and gbm[-1] == (114, 64), (len(gbm), gbm[-2:]))
m = send(c, amount=12, time=200, shape=1, click=0)
step_t = gen_patches.gb_step_t(200)
check("STEP +12, 200 ms: CC 89 = 1 (STEP) on pulse 1, pulse 2 and the wave", all(m[ch].get(89) == 1 for ch in range(3)), [m[ch].get(89) for ch in range(3)])
check("... CC 81 = the hold time (step frames 12: 200 ms)", gen_patches.GB_STEP[step_t] == 12 and all(m[ch].get(81, None) in (None, gen_patches.cc(step_t, 15)) for ch in range(3))
      and m[0].get(81) == gen_patches.cc(step_t, 15), (m[0].get(81), gen_patches.cc(step_t, 15)))
m = send(c, amount=12, time=200, shape=0, click=1)
check("SLIDE + CLICK SHORT: CC 89 = 2", all(m[ch].get(89) == 2 for ch in range(3)), [m[ch].get(89) for ch in range(3)])
m = send(c, amount=0, time=150, shape=1, click=2)
check("AMOUNT 0 (just a LONG CLICK): CC 89 = 4 (no STEP without an AMOUNT)", all(m[ch].get(89) == 4 for ch in range(3)), [m[ch].get(89) for ch in range(3)])
m = send(c, amount=12, time=200, shape=0, click=0)
check("SLIDE, no click: CC 89 = 0", all(m[ch].get(89) == 0 for ch in range(3)), [m[ch].get(89) for ch in range(3)])

# ---------------------------------------------------------------- end to end
c = C64(channels=None)
c.run_ms(500)
send(c, amount=12, time=200, shape=1, click=0)
c.run_ms(200)
t_note = c.cpu.processorCycles
c.midi_in(0x90, 60, 100, ms=600)
wire, lost = forward(list(c.tx))
gb = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
gb.run(120)
FRAME = CYCLES_PER_MS * 1000 / 59.7275
t0 = wire[0][0]
i, frame, seq = 0, 0, []
vs = gb.sym["_voice"]
while i < len(wire) or frame < 10:
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        i += 1
    if chunk:
        gb.midi(*chunk)
    gb.run(1)
    if limit >= t_note:
        per = gb.mem(vs + 34) | (gb.mem(vs + 35) << 8)
        if gb.mem(vs) == 60 and per and per != 0xFFFF:
            seq.append(round(69 + 12 * math.log2(131072 / per / 440)))
    frame += 1
check("end to end: the Game Boy's BEND SHAPE is STEP", gb.var("_patch", 32)[23] == 1, gb.var("_patch", 32)[23])
held = seq[:8]
check("end to end: pulse 1 holds an octave up, then jumps to the note", held and set(held) == {72} and 60 in seq
      and all(n in (60, 72) for n in seq), seq[:20])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
