#!/usr/bin/env python3
"""Fat Chip 64 v0.14: keys (RETURN menu, F1/F3 octave, F5 beat, F7
visualizer), latch NEXT, BEAT TEMPO, the sound switches and ADVANCED SOUND,
FILTER SWEEP, BEAT FILL, TAPE WOBBLE, WIDE, the new play screen, the
visualizer."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0
GB = (10, 11, 12)
DMC, NOISE = 4, 3
A_SWEEP, A_FILL, A_WOBBLE, A_WIDE = 12, 13, 14, 15


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def since(c, t0):
    return [(t, s, a, b) for t, s, a, b in c.midi(since=t0)]


def ccs(c, t0, cc):
    return [(s & 15, b) for _, s, a, b in since(c, t0) if (s & 0xF0) == 0xB0 and a == cc]


def sid_freq(c, v):
    return c.sid(v)[0]


def taps(c, gap, n=4):
    """B tapped n times, gap ms apart."""
    for _ in range(n):
        c.press("b", ms=gap // 2)
        c.release("b", ms=gap - gap // 2)


c = C64(channels=None)
c.run_ms(400)

# ---------------------------------------------------------------- play screen
rows = [c.screen_row(r) for r in range(25)]
check("header: V0.14, RETURN: MENU", rows[0].startswith(" FAT CHIP 64  V0.33") and rows[0].endswith("RETURN: MENU "), rows[0])
check("one line per chip: SID ON, GAME BOY 11-15, MIDINES 1-5",
      rows[4].startswith("SID      ON ") and rows[5].startswith("GAME BOY 11-15") and rows[6].startswith("MIDINES  1-5 "),
      rows[4:7])
check("key, mode, latch on one line", rows[9].rstrip() == "KEY C  MAJOR      POLY      LATCH OFF", rows[9])
check("help line: F keys", rows[24].startswith("F1/F3 OCTAVE  F5 ARP  F7 VIZ  STOP BEAT"), rows[24])
check("no N / NEW CHORD left on the screen", not any("NEW" in r or "N NEXT" in r for r in rows), rows)
c.press("q", "e", "t", ms=200)
check("SID line: its three notes", c.screen_row(4)[16:].split() == ["G", "3", "E", "3", "C", "3"]
      or set(c.screen_row(4)[16:].replace(" 3", "3").split()) <= {"C3", "E3", "G3"}, c.screen_row(4))
check("NES line: the triangle's bass C 2", c.screen_row(6)[28:31] == "C 2", c.screen_row(6))
c.release("q", "e", "t", ms=200)

# ---------------------------------------------------------------- keys
c.tap("f1", ms=60)
check("F1: an octave up", c.v("octBase") == 60)
c.tap("f3", ms=60)
check("F3: back down", c.v("octBase") == 48)
c.press("lshift", ms=10); c.tap("return", ms=60); c.release("lshift", ms=10)
check("SHIFT+RETURN on the play screen: nothing", c.v("menuOn") == 0 and c.v("beatRun") == 0)

# ---------------------------------------------------------------- BEAT TEMPO
check("power on: 120 BPM, ELECTRO chosen", c.v("bpm") == 120 and c.v("beatSel") == 0)
c.tap("f5", ms=200)
check("F5: the beat starts at its own tempo (ELECTRO 124)", c.v("beatRun") == 1 and c.v("bpm") == 124, c.v("bpm"))
taps(c, 600)
check("tap: 100 BPM", abs(c.v("bpm") - 100) <= 1, c.v("bpm"))
c.tap("f5", ms=100); c.tap("f5", ms=150)
check("F5 F5: stopped and started again, the tapped tempo kept", c.v("beatRun") == 1 and abs(c.v("bpm") - 100) <= 1, c.v("bpm"))
c.tap("g", ms=150)
check("G: a new beat (JUNGLE) sets its tempo (168)", c.v("bpm") == 168, c.v("bpm"))
c.tap("f5", ms=100)
c.set("beatTempo", 1)                        # IGNORE
c.run_ms(2100)                               # (a fresh set of taps)
taps(c, 500)
c.tap("g", ms=150)
check("BEAT TEMPO IGNORE: G keeps the tempo (120)", c.v("beatSel") == 2 and abs(c.v("bpm") - 120) <= 1, c.v("bpm"))
c.tap("f5", ms=150)
check("... and so does starting it", c.v("beatRun") == 1 and abs(c.v("bpm") - 120) <= 1, c.v("bpm"))
c.tap("f5", ms=100)
c.set("beatTempo", 0)
c.tap("g", ms=20); c.tap("g", ms=20); c.tap("g", ms=20); c.tap("g", ms=150)   # DNB -> round to ELECTRO
check("back to ELECTRO, 124", c.v("beatSel") == 0 and c.v("bpm") == 124, (c.v("beatSel"), c.v("bpm")))

# (v0.24: the old menu's VIBRATO / GLIDE / DETUNE / TREMOLO / MONO / WARBLE
# switches are gone: the PATCH pages edit the patch itself, test_v024.py)
c.midi_in(0xC0, 0, ms=300)
c.press("q", ms=200)
c.set("uDet", 1)

# WIDE held
c.set("spaceAct", A_WIDE)
t0 = c.cpu.processorCycles
c.press("space", ms=100)
f = [sid_freq(c, v) for v in range(3)]
pan = [x for x in ccs(c, t0, 10) if x[0] in GB]
det = [x for x in ccs(c, t0, 94) if x[0] in GB]
check("WIDE held: SID detune 22, the held notes spread", c.v("detNow") == 22 and f[1] - f[2] > 0, (c.v("detNow"), f))
check("WIDE held: Game Boy pulses panned apart, detuned wider (FAT's 64 -+ 8, v0.19, then -+ 20)", (10, 0) in pan and (11, 127) in pan
      and (10, 44) in det and (11, 84) in det, (pan, det))
t0 = c.cpu.processorCycles
c.release("space", ms=100)
pan = [x for x in ccs(c, t0, 10) if x[0] in GB]
check("WIDE let go: back (detune 8, pans centred)", c.v("detNow") == 8 and (10, 64) in pan and (11, 64) in pan, pan)

# TAPE WOBBLE held
c.set("spaceAct", A_WOBBLE)
t0 = c.cpu.processorCycles
c.press("space", ms=100)
wb = [b for _, s, a, b in since(c, t0) if s == 0xBA and a == 104]
check("TAPE WOBBLE held: deep slow spread SID vibrato, Game Boy warble 110", c.v("vibDepth") == 110 and c.v("vibSpr") == 1
      and wb[-1:] == [110], (c.v("vibDepth"), wb))
f = []
for _ in range(60):
    c.run_ms(20)
    f.append(sid_freq(c, 0))
check("TAPE WOBBLE: the pitch drifts", max(f) - min(f) > 30, (min(f), max(f)))
t0 = c.cpu.processorCycles
c.release("space", ms=100)
wb = [b for _, s, a, b in since(c, t0) if s == 0xBA and a == 104]
check("TAPE WOBBLE let go: FAT again (no vibrato, warble 24)", c.v("vibDepth") == 0 and wb[-1:] == [24], wb)

# FILTER SWEEP on FAT (no filter): the low-pass comes in and closes
c.set("spaceAct", A_SWEEP)
c.press("space", ms=40)
cut1 = c.raw[0xD416]
c.run_ms(200)
cut2 = c.raw[0xD416]
check("FILTER SWEEP held (unfiltered sound): low-pass on, resonance, closing", c.raw[0xD417] == 0xE7
      and c.raw[0xD418] & 0x70 == 0x10 and cut2 < cut1, (hex(c.raw[0xD417]), cut1, cut2))
c.release("space", ms=40)
c.run_ms(400)
check("let go: it opens and switches off", c.raw[0xD417] == 0 and c.raw[0xD418] & 0x70 == 0 and c.v("sweepLvl") == 0)
c.release("q", ms=100)

# FILTER SWEEP on PADS (filtered): it opens up
c.release("q", ms=60)
c.tap("v", ms=300)
c.press("q", ms=100)
base = max(c.raw[0xD416] for _ in [c.run_ms(5) for _ in range(20)])
c.press("space", ms=400)
cut = c.raw[0xD416]
check("FILTER SWEEP on PADS: the cutoff opens towards the top", cut > 230 and base < 140, (base, cut))
c.release("space", ms=400)
check("let go: back down, PADS's filter stays on", c.raw[0xD416] < 140 and c.raw[0xD417] != 0, (c.raw[0xD416], hex(c.raw[0xD417])))
c.release("q", ms=60)
c.press("lshift", ms=10); c.tap("v", ms=300); c.release("lshift", ms=10)
c.press("q", ms=100)

# ---------------------------------------------------------------- BEAT FILL
c.set("spaceAct", A_FILL)
c.tap("f5", ms=600)
t0 = c.cpu.processorCycles
c.press("space", ms=1000)
d = [a for _, s, a, b in since(c, t0) if s == 0x94 and b]
hats = [a for _, s, a, b in since(c, t0) if s == 0x93 and b]
check("BEAT FILL held: snare and tom samples, no hats", len(d) >= 8 and {47, 46, 43} & set(d) and not hats, (d, hats))
t0 = c.cpu.processorCycles
c.release("space", ms=200)
cy = [a for _, s, a, b in since(c, t0) if s == 0x93 and b]
check("BEAT FILL let go: a crash, the beat goes on", 48 in cy and c.v("beatRun") == 1, cy)
c.tap("f5", ms=300)
check("F5: stopped", c.v("beatRun") == 0)
t0 = c.cpu.processorCycles
c.press("space", ms=600)
check("BEAT FILL with no beat: the fill plays on its own", c.v("beatRun") == 1
      and len([1 for _, s, a, b in since(c, t0) if s == 0x94 and b]) >= 3)
t0 = c.cpu.processorCycles
c.release("space", ms=400)
cy = [a for _, s, a, b in since(c, t0) if s == 0x93 and b]
check("... let go: a crash, and it stops", 48 in cy and c.v("beatRun") == 0, (cy, c.v("beatRun")))
c.set("spaceAct", 1)

# ---------------------------------------------------------------- visualizer (v0.28: GLITCH only; test_v015.py)
c.tap("f7", ms=150)
check("F7: the visualizer (GLITCH)", c.v("vizOn") == 2)
c.tap("return", ms=60)
check("RETURN: the menu from the visualizer", c.v("menuOn") == 1 and "MENU" in c.screen_row(0))
c.tap("f7", ms=60)
check("F7 in the menu (v0.26: changes the line): HELP opens, the visualizer stays", c.v("vizOn") == 2 and c.v("menuOn") == 1
      and "HELP" in c.screen_row(0))
c.press("lshift", ms=10); c.tap("return", ms=100); c.tap("return", ms=100); c.release("lshift", ms=100)
check("closing the menu: back to the visualizer", c.v("menuOn") == 0 and c.v("vizOn") == 2)
c.tap("f7", ms=200)
check("F7: the play screen again", c.v("vizOn") == 0 and c.screen_row(4).startswith("SID") and c.raw[0xD800 + 4 * 40] & 15 == 13)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
