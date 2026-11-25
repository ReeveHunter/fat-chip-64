#!/usr/bin/env python3
"""Fat Chip 64 v0.58 (Fat Chip GB v0.15): VIBRATO SYNC and PWM SYNC. A
division (1 BAR ... 1/32) sets the LFO from the tempo, on the SID and the NES
(their phase step per 4 ms: 262144 / beats / beat ms) and the Game Boy (CC 91
LFO SYNC: it runs its LFO from the tempo itself, back to the start on the
downbeat). The menu's VIBRATO and PWM pages have a SYNC line."""
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


def u16(c, lo, hi):
    return c.v(lo) | c.v(hi) << 8


def beat(c):
    return c.v("beatMs") | c.v("beatMs", 2)[1] << 8


def send(c, **fx):
    p = copy.deepcopy(P[2])
    for k, v in fx.items():
        p["fx"][k] = v
    t0 = c.cpu.processorCycles
    c.midi_in(*gen_patches.sysex(p), ms=400)
    return t0


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(500)
check("header V0.66", "V0.66" in c.screen_row(0), c.screen_row(0))
t0 = send(c, vibrato={"depth": 30, "vibRate": 5.5, "vibSync": 3})
bm = beat(c)
check("VIBRATO SYNC 1/4: the SID / NES vibrato step from the tempo (262144 / beat ms)", abs(u16(c, "vibRL", "vibRH") - 262144 // bm) <= 1,
      (u16(c, "vibRL", "vibRH"), 262144 // bm, bm))
gb = c.v("gbBase")
m = [((s & 15) - gb, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 91 and 0 <= (s & 15) - gb < 2]
check("... the Game Boy's pulses: CC 91 LFO SYNC = 3", sorted(m) == [(0, 3), (1, 3)], m)
# a new tempo (as TempoUp would): 150 BPM
c.set("beatFresh", 0)
T = 0xCF80
a = c.sym["SetBpm"]
cpu = c.cpu
saved = (cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p)
for k, b in enumerate([0x20, a & 255, a >> 8, 0x4C, (T + 3) & 255, (T + 3) >> 8]):
    c.raw[T + k] = b
cpu.pc, cpu.a = T, 150
while cpu.pc != T + 3:
    c.step()
cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p = saved
c.run_ms(100)
bm2 = beat(c)
check("a new tempo (150 BPM): the vibrato follows", bm2 == 400 and abs(u16(c, "vibRL", "vibRH") - 262144 // bm2) <= 1, (bm2, u16(c, "vibRL", "vibRH")))
t0 = send(c, pwm={"depth": 50, "pwmRate": 0.5, "pwmSync": 1})
check("PWM SYNC 1 BAR: the SID's width LFO step from the tempo (65536 / beat ms)", abs(u16(c, "pwmRL", "pwmRH") - 65536 // bm2) <= 1,
      (u16(c, "pwmRL", "pwmRH"), 65536 // bm2))
send(c, pwm={"depth": 50, "pwmRate": 0.5})
r = gen_patches.inc4(0.5)
check("PWM FREE: the patch's own rate", u16(c, "pwmRL", "pwmRH") == r, (u16(c, "pwmRL", "pwmRH"), r))

# the menu: VIBRATO's and PWM's pages have SYNC (the generated menu)
menu = open(os.path.join(HERE, "..", "src", "menuhi.asm")).read()
check("the menu: SYNC lines for TREMOLO, VIBRATO and PWM", menu.count('"SYNC ",0') >= 3, menu.count('"SYNC ",0'))

# ---------------------------------------------------------------- end to end: the Game Boy's LFO from the tempo
c = C64(channels=None)
c.run_ms(500)
send(c, vibrato={"depth": 30, "vibRate": 5.5, "vibSync": 5})
c.midi_in(0x90, 60, 100, ms=800)
wire, lost = forward(list(c.tx))
g = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
g.run(120)
FRAME = CYCLES_PER_MS * 1000 / 59.7275
t0 = wire[0][0]
i, frame = 0, 0
while i < len(wire):
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        i += 1
    if chunk:
        g.midi(*chunk)
    g.run(1)
    frame += 1
tempo32 = g.var("_tempo32") | g.var("_tempo32", 2)[1] << 8
bpm = tempo32 / 32
sinc = g.var("_lfo_sinc", 2)[0] | g.var("_lfo_sinc", 2)[1] << 8
want = 65536 * (bpm / 60 * 2) / 59.7275                       # 1/8: two cycles a beat, a step a frame
check("end to end: the Game Boy's pulse 1 LFO runs at 1/8 of the tempo", g.var("_lfo_sync", 3)[0] == 5 and abs(sinc - want) / want < 0.02,
      (g.var("_lfo_sync", 3), sinc, round(want), bpm))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
