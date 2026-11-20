#!/usr/bin/env python3
"""Fat Chip 64 v0.56 (Fat Chip GB v0.14): in DRONE the Game Boy's glides ease
in and out (CC 90 EASED GLIDE = 90 frames, about the SID's 1.5 s), each
voice at its own moment as Fat Chip 64 staggers them; out of DRONE, CC 90 =
0 (the usual glide). End to end through the Game Boy ROM."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import C64, CYCLES_PER_MS  # noqa: E402
from teensy import forward  # noqa: E402

GB_REPO = os.environ.get("FATCHIP_GB", os.path.join(HERE, "..", "..", "fat-chip-gb"))
sys.path.insert(0, os.path.join(GB_REPO, "test"))
from harness import GB  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def cc90(c, t0):
    gb = c.v("gbBase")
    return [((s & 15) - gb, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 90 and 0 <= (s & 15) - gb < 3]


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(500)
check("header V0.60", "V0.60" in c.screen_row(0), c.screen_row(0))
t0 = c.cpu.processorCycles
c._raw_press("ctrl", ms=30); c._raw_tap("crsrdown", ms=40); c._raw_release("ctrl", ms=200)
m = cc90(c, t0)
check("CTRL + CRSR: DRONE: CC 90 = 90 (eased, 1.5 s) on pulse 1, pulse 2 and the wave", c.v("playMode") == 2 and sorted(m) == [(0, 90), (1, 90), (2, 90)], m)
c._raw_tap("l", ms=40)                                       # latch
c.press("q", ms=200)
c.release("q", ms=3000)
c.press("t", ms=20)                                          # a new drone: G
c.release("t", ms=4000)
t_end = c.cpu.processorCycles
c._raw_tap("l", ms=100)                                      # latch off (a mode change then applies at once)
t0 = c.cpu.processorCycles
c._raw_press("ctrl", ms=30); c._raw_tap("crsrdown", ms=40); c._raw_release("ctrl", ms=200)
m = cc90(c, t0)
check("CTRL + CRSR again (POLY): CC 90 = 0", c.v("playMode") == 0 and sorted(m) == [(0, 0), (1, 0), (2, 0)], m)

# ---------------------------------------------------------------- end to end: the drone's glides on the Game Boy
wire, lost = forward([(t, b) for t, b in c.tx if t <= t_end])
gb = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
gb.run(120)
FRAME = CYCLES_PER_MS * 1000 / 59.7275
t0 = wire[0][0]
i, frame = 0, 0
vs = gb.sym["_voice"]
pit = [[] for _ in range(3)]
while i < len(wire):
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        i += 1
    if chunk:
        gb.midi(*chunk)
    gb.run(1)
    for v in range(3):
        p = gb.mem(vs + v * 48 + 14) | gb.mem(vs + v * 48 + 15) << 8
        pit[v].append((p - 65536 if p > 32767 else p) / 256)
    frame += 1
check("end to end: the Game Boy took EASED GLIDE 90 on its pulses and wave", gb.var("_ease_len", 3) == [90, 90, 90], gb.var("_ease_len", 3))
for _ in range(150):                                         # (2.5 s more)
    gb.run(1)
    for v in range(3):
        p = gb.mem(vs + v * 48 + 14) | gb.mem(vs + v * 48 + 15) << 8
        pit[v].append((p - 65536 if p > 32767 else p) / 256)
glides = []
for v in range(3):
    s_ = pit[v]
    old, new = s_[200], s_[-1]                                # (the C drone by frame 200; the G one at the end)
    if abs(new - old) < 1:
        continue
    leave = next(k for k in range(200, len(s_)) if abs(s_[k] - old) > 1e-6)
    arrive = next(k for k in range(leave, len(s_)) if abs(s_[k] - new) < 0.02)
    mid = s_[(leave + arrive) // 2]
    glides.append((v, old, new, leave, arrive - leave, round((mid - old) / (new - old), 2)))
check("the drone change: every Game Boy voice glides to its new note", len(glides) == 3, glides)
check("... each over about 1.5 s (90 frames; the first and last steps too small to hear)", glides and all(80 <= g[4] <= 120 for g in glides), [(g[0], g[4]) for g in glides])
check("... half way at the middle (an S curve)", glides and all(0.35 <= g[5] <= 0.65 for g in glides), [(g[0], g[5]) for g in glides])
check("... starting at different moments (staggered, as on the C64)", len(set(g[3] for g in glides)) == len(glides) >= 2, [(g[0], g[3]) for g in glides])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
