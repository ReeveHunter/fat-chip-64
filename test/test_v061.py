#!/usr/bin/env python3
"""Fat Chip 64 v0.61: the 25 beats (patch/beats.json). Each beat's lanes are
A, B or both; RUN/STOP + N picks the part, H a hat layer, J an accent layer,
K the time signature, L the swing. The menu's BEATS page: those, and BEATS ON
(MIDINES / GAME BOY / BOTH), BOTH (LAYER / SPLIT), GAME BOY HATS. A beat that
is playing keeps the tempo when another is chosen (test_v014)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim import C64, CYCLES_PER_MS  # noqa: E402
import gen_beats  # noqa: E402
C64.keys_039 = False                         # (the keys as they are: RUN/STOP + H is the hat layer now)

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def stop_key(c, k, ms=60):
    c._raw_press("runstop", ms=30)
    c._raw_tap(k, ms=40)
    c._raw_release("runstop", ms=ms)


def pick(c, n):
    for _ in range(26):
        if c.v("beatSel") == n:
            break
        stop_key(c, ";")
    c.run_ms(80)


def start(c):
    if not c.v("beatRun"):
        c._raw_tap("runstop", ms=40)


def stop(c):
    if c.v("beatRun"):
        c._raw_tap("runstop", ms=40)
    c.run_ms(300)


DMC, NOISE = 4, 3
TOMS = {47, 46, 43}


def play(c, ms):
    t0 = c.cpu.processorCycles
    start(c)
    c.run_ms(ms)
    return [(round((t - t0) / CYCLES_PER_MS), s, a, b) for t, s, a, b in c.midi(since=t0)]


c = C64(channels=None)
c.run_ms(300)
check("header V0.64", "V0.64" in c.screen_row(0), c.screen_row(0))
check("25 beats in five banks", len(gen_beats.BEATS) == 25 and c.sym["NUM_BEATS"] == 25 if "NUM_BEATS" in c.sym else len(gen_beats.BEATS) == 25)
names = [b["name"] for b in gen_beats.BEATS]
check("the first beat: ROCK, part A, 4/4", c.v("beatSel") == 0 and c.v("beatPart") == 0 and c.v("cycLen") == 32
      and "A    ROCK" in c.screen_row(12), c.screen_row(12))

# ---------------------------------------------------------------- the part
step = 60000 / 116 / 4
bar2 = int(32 * step) + 100
m = play(c, bar2)
toms = [a for t, s, a, b in m if s == 0x90 | DMC and b and a in TOMS]
check("ROCK, part A: no toms (B's fill)", not toms, toms)
stop(c)
stop_key(c, "n")
check("RUN/STOP + N: part B (screen B)", c.v("beatPart") == 1 and c.screen_row(12)[15:19] == "B   ", c.screen_row(12))
m = play(c, bar2)
toms = [a for t, s, a, b in m if s == 0x90 | DMC and b and a in TOMS]
check("part B: the fill's toms (hi, mid, lo)", set(toms) == TOMS, toms)
stop(c)
stop_key(c, "n")
stop_key(c, "n")
check("N N: A<->B (screen ALT)", c.v("beatPart") == 3 and c.screen_row(12)[15:19] == "ALT ", c.screen_row(12))
m = play(c, 2 * bar2)
loop1 = [a for t, s, a, b in m if s == 0x90 | DMC and b and a in TOMS and t < bar2 - 100]
loop2 = [a for t, s, a, b in m if s == 0x90 | DMC and b and a in TOMS and t >= bar2 - 100]
check("A<->B: A the first time round, B the next", not loop1 and set(loop2) == TOMS, (loop1, loop2))
stop(c)
stop_key(c, "n")
check("N: round to A", c.v("beatPart") == 0)

# ---------------------------------------------------------------- the accent layer (open hats: no random level)
pick(c, 1)                                          # DISCO: open hats on the off-beats, OFFBEAT accents
check("DISCO chosen (120 BPM: stopped, so its own)", "DISCO" in c.screen_row(12) and c.v("bpm") == 120, c.screen_row(12))


def open_levels(m):
    lv, out = None, []
    for t, s, a, b in m:
        if s == 0xB0 | NOISE and a == 7:
            lv = b
        if s == 0x90 | NOISE and b and a == 49:     # (the open hat's noise note)
            out.append(lv)
    return out


hats = [h["name"] for h in gen_beats.DOC["hatLayers"]]
c.set("beatHats", hats.index("OFFBEAT") + 1)      # (open hats only: closed ones vary their note)
m = play(c, 2100)
lv = open_levels(m)
check("OFFBEAT accents (DISCO's): the off-beat open hats strong (CC7 56)", lv and all(x == 56 for x in lv), lv[:6])
stop(c)
for _ in range(1):
    stop_key(c, "j")                                # BEAT'S -> FLAT
check("RUN/STOP + J: FLAT", c.v("beatAcc") == 1)
m = play(c, 2100)
lv = open_levels(m)
check("FLAT: every open hat normal (CC7 48)", lv and all(x == 48 for x in lv), lv[:6])
stop(c)
c.set("beatAcc", 0)

# ---------------------------------------------------------------- hat layers
c.set("beatHats", hats.index("TRIPLETS") + 1)
m = play(c, 2100)
ch = [t for t, s, a, b in m if s == 0x90 | NOISE and b and a in (49, 50, 51)]
gaps = [b - a for a, b in zip(ch, ch[1:])]
third = 60000 / 120 / 3
check("TRIPLETS: closed hats a third of a beat apart (167 ms)", len(ch) >= 9 and all(abs(g - third) <= 8 for g in gaps[1:]),
      gaps[:8])
stop(c)
c.set("beatHats", hats.index("NONE") + 1)
m = play(c, 1100)
nz = [a for t, s, a, b in m if s == 0x90 | NOISE and b]
check("NONE: no hats", not nz, nz)
stop(c)
c.set("beatHats", 0)
stop_key(c, "h")
check("RUN/STOP + H steps the hat layer", c.v("beatHats") == 1)
c.set("beatHats", 0)

# ---------------------------------------------------------------- time signature
pick(c, 0)                                          # ROCK (116: stopped)
stop_key(c, "k"); stop_key(c, "k"); stop_key(c, "k"); stop_key(c, "k")
ts = [t["name"] for t in gen_beats.DOC["timeSigs"]]
check("RUN/STOP + K x4: 7/4 (4+3), a cycle of 28 steps", ts[c.v("beatTs")] == "7/4 (4+3)" and c.v("cycLen") == 28,
      (c.v("beatTs"), c.v("cycLen")))
step = 60000 / 116 / 4
m = play(c, int(2 * 28 * step) + 60)
kicks = [t for t, s, a, b in m if s == 0x90 | DMC and b and a in (92, 68, 91)]   # ROCK's kicks
# ROCK A's kicks: bar 1 steps 0, 8, 10; bar 2 (16..27): 16, 24, 26; then again from 28
want = [0, 8, 10, 16, 24, 26, 28, 36, 38]
got = [round((t - kicks[0]) / step) for t in kicks][:9]
check("7/4: the beat's first 16 steps, then 12 of its second bar, round again", got == want, got)
stop(c)
c.set("beatTs", 0)
stop_key(c, "k")                                    # (on to 3/4 ...)
c.set("beatTs", 0)
stop_key(c, "l")                                    # (swing: OFF)
c.set("beatTs", 0)
c.set("beatSwg", 0)
c.run_ms(50)

# ---------------------------------------------------------------- swing
pick(c, 21)                                         # BOOM BAP: 55% (test_v012); swing 66% over it
c.set("beatSwg", 5)                                 # (66%)
c.set("beatTs", 0)
stop_key(c, "k"); c.set("beatTs", 0)               # (rebuild the 4/4 cycle)
step = 60000 / 90 / 4
m = play(c, int(16 * step) + 60)
hits = [t for t, s, a, b in m if s == 0x90 | DMC and b]
rel = [round(x - hits[0]) for x in hits]
check("SWING 66%: the odd step 7 kick +55 ms (half a step x 66%)", len(rel) >= 3 and abs(rel[2] - (7 * step + 0.33 * step)) <= 8,
      rel[:4])
stop(c)
c.set("beatSwg", 0)

# ---------------------------------------------------------------- the Game Boy plays the beats
gb_drum = (c.v("gbBase") + 4) & 15
pick(c, 0)
c.set("beatDev", 1)                                 # GAME BOY
m = play(c, 1200)
gbn = [(a, b) for t, s, a, b in m if s == 0x90 | gb_drum and b]
nes = [x for x in m if (x[1] & 15) in (DMC, NOISE) and x[1] & 0xF0 == 0x90 and x[3]]
cc = [(a, b) for t, s, a, b in m if s == 0xB0 | gb_drum and a in (70, 71)]
check("BEATS ON GAME BOY: kick 36 / snare 38 / hat 42 notes on its drum channel", {36, 38, 42} <= {a for a, b in gbn}, gbn[:6])
check("... the NES plays no drums", not nes, nes[:4])
check("... its kit for ROCK (909: CC 70 = 64) and HATS SAMPLE (CC 71 = 0)", (70, 64) in cc and (71, 0) in cc, cc)
check("... and its wave channel is the drums' while it plays (no synth note on it)", c.v("vDrum", 9)[7] == 1, c.v("vDrum", 9))
vel = sorted({b for a, b in gbn if a == 42})
check("... velocities from the accent layer (BACKBEAT: soft 56 / normal 100)", vel and set(vel) <= {56, 100, 127} and len(vel) >= 2, vel)
stop(c)
c.run_ms(100)
check("stopped: the wave channel back to the synth", c.v("vDrum", 9)[7] == 0)
c.set("gbBtHats", 1)
m = play(c, 300)
cc = [(a, b) for t, s, a, b in m if s == 0xB0 | gb_drum and a == 71]
check("GAME BOY HATS NOISE: CC 71 = 127", (71, 127) in cc, cc)
stop(c)
c.set("gbBtHats", 0)
c.set("beatDev", 2)                                 # BOTH, LAYER
m = play(c, 1200)
gbn = {a for t, s, a, b in m if s == 0x90 | gb_drum and b}
nes = [a for t, s, a, b in m if s == 0x90 | DMC and b]
check("BOTH, LAYER: kick and snare on both", {36, 38} <= gbn and nes, (gbn, nes[:4]))
stop(c)
c.set("beatSplit", 1)                               # SPLIT
m = play(c, 1200)
gbn = {a for t, s, a, b in m if s == 0x90 | gb_drum and b}
nes_dmc = [a for t, s, a, b in m if s == 0x90 | DMC and b]
nes_nz = [a for t, s, a, b in m if s == 0x90 | NOISE and b]
check("BOTH, SPLIT: the NES the kick and snare, the Game Boy the hats", gbn and gbn <= {42, 46, 49, 51, 70, 56, 75}
      and nes_dmc and not nes_nz, (gbn, nes_dmc[:3], nes_nz[:3]))
stop(c)
c.set("beatSplit", 0)
c.set("beatDev", 0)

# ---------------------------------------------------------------- the menu page
c.tap("return", ms=80)
for _ in range(10):
    if c.screen_row(c.v("menuRow") + 2 if False else 0) and any(r.startswith("> BEATS") for r in [c.screen_row(i) for i in range(25)]):
        break
    c.tap("crsrdown", ms=30)
c.tap("return", ms=80)
rows = [c.screen_row(i) for i in range(25)]
check("menu BEATS: part, hat layer, accent, time, swing, BEATS ON, BOTH, GAME BOY HATS",
      all(any(r[2:].startswith(x) for r in rows) for x in ("PART", "HAT LAYER", "ACCENT", "TIME", "SWING", "BEATS ON", "BOTH", "GAME BOY HATS")),
      rows[2:13])
c.press("lshift", ms=10); c.tap("return", ms=80); c.tap("return", ms=80); c.release("lshift", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
