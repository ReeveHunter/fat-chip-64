#!/usr/bin/env python3
"""Fat Chip 64 v0.14: keys (RETURN menu, F1/F3 octave, F5 beat, F7
visualizer), latch NEXT, BEAT TEMPO, the sound switches and ADVANCED SOUND,
FILTER SWEEP, BEAT FILL, TAPE WOBBLE, WIDE, the new play screen, the
visualizer."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

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


def menu_set(c, row, steps):
    """Menu item `row` (index), CRSR RIGHT `steps` times, then back to play."""
    c.set("menuRow", row)
    c.tap("return", ms=60)
    for _ in range(steps):
        c.tap("crsrright", ms=40)
    c.press("lshift", ms=10); c.tap("return", ms=60); c.release("lshift", ms=150)


c = C64(channels=None)
c.run_ms(400)

# ---------------------------------------------------------------- play screen
rows = [c.screen_row(r) for r in range(25)]
check("header: V0.14, RETURN: MENU", rows[0].startswith(" FAT CHIP 64  V0.15") and rows[0].endswith("RETURN: MENU "), rows[0])
check("one line per chip: SID ON, GAME BOY 11-15, MIDINES 1-5",
      rows[4].startswith("SID      ON ") and rows[5].startswith("GAME BOY 11-15") and rows[6].startswith("MIDINES  1-5 "),
      rows[4:7])
check("key, mode, latch on one line", rows[9].rstrip() == "KEY C  MAJOR  POLY         LATCH OFF", rows[9])
check("help line: F keys", rows[24].startswith("F1/F3 OCTAVE   F5 BEAT   F7 VISUALIZER"), rows[24])
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

# ---------------------------------------------------------------- sound switches
# FAT has no vibrato: the menu's VIBRATO ON gives the ADVANCED SOUND one
t0 = c.cpu.processorCycles
menu_set(c, 2, 1)                            # VIBRATO -> ON
check("VIBRATO ON: SID vibrato from ADVANCED SOUND (1/4 semitone, 6 Hz)",
      c.v("vibLock") == 1 and c.v("vibDepth") == 61 and c.v("vibRL") | c.v("vibRH") << 8 == 1572, c.v("vibDepth"))
lfo = [x for x in ccs(c, t0, 1) if x[0] in GB]
rate = [x for x in ccs(c, t0, 76) if x[0] in GB]
check("VIBRATO ON: Game Boy pulses LFO to pitch, depth CC 24, rate CC 92", (10, 24) in lfo and (11, 24) in lfo
      and (10, 92) in rate, (lfo, rate))
c.press("q", ms=50)
f = []
for _ in range(40):
    c.run_ms(10)
    f.append(sid_freq(c, 0))
check("VIBRATO ON: the SID wobbles", max(f) - min(f) > 20, (min(f), max(f)))
c.release("q", ms=50)
c.set("uVibDep", 3)                          # 1/2 semitone (ADVANCED SOUND, set as its hook would)
c.set("menuRow", 14)
c.tap("return", ms=60)
check("RETURN on a closed page's line? (menuRow 14 is on ADVANCED SOUND: MenuOpen goes to the main page)", c.v("menuPage") == 0)
c.press("lshift", ms=10); c.tap("return", ms=100); c.release("lshift", ms=100)
c.set("menuRow", 8); c.tap("return", ms=60); c.tap("return", ms=80)       # main page -> ADVANCED SOUND
c.tap("crsrright", ms=60)                    # VIBRATO DEPTH: 1/2 -> 1/8 (wraps)
check("ADVANCED SOUND: VIBRATO DEPTH 1/8 applies at once (VIBRATO is ON)", c.v("uVibDep") == 0 and c.v("vibDepth") == 30,
      (c.v("uVibDep"), c.v("vibDepth")))
c.press("lshift", ms=10); c.tap("return", ms=60); c.tap("return", ms=60); c.release("lshift", ms=150)
c.set("uVibDep", 1)
menu_set(c, 2, 1)                            # VIBRATO -> OFF
check("VIBRATO OFF", c.v("vibLock") == 2 and c.v("vibDepth") == 0)
c.set("vibBtn", 1); c.set("menuRow", 2); c.tap("return", ms=40)
c.tap("crsrright", ms=40); c.tap("crsrright", ms=40)     # OFF -> AS SOUND -> ON -> (OFF again below)
c.press("lshift", ms=10); c.tap("crsrright", ms=40); c.release("lshift", ms=10)
c.press("lshift", ms=10); c.tap("return", ms=60); c.release("lshift", ms=100)
check("(VIBRATO back to AS SOUND)", c.v("vibLock") == 0, c.v("vibLock"))
c.set("vibBtn", 0)

# WHISTLE has vibrato on the SID and the Game Boy: OFF takes both away
c.midi_in(0xC0, 4, ms=300)
check("WHISTLE (sound vibrato)", c.v("soundMode") == 4 and c.v("vibDepth") > 0)
t0 = c.cpu.processorCycles
menu_set(c, 2, 2)                            # VIBRATO -> OFF
lfo = [x for x in ccs(c, t0, 1) if x[0] in GB]
check("WHISTLE + VIBRATO OFF: no SID vibrato, the Game Boy's pitch LFO depth 0", c.v("vibDepth") == 0 and (10, 0) in lfo
      and (11, 0) in lfo, lfo)
menu_set(c, 2, 1)                            # -> AS SOUND
check("VIBRATO AS SOUND: WHISTLE's own again", c.v("vibDepth") == 61, c.v("vibDepth"))

# GLIDE ON on FAT
t0 = c.cpu.processorCycles
c.midi_in(0xC0, 0, ms=300)
menu_set(c, 3, 1)                            # GLIDE -> ON
gl = [x for x in ccs(c, t0, 5) if x[0] in GB]
check("GLIDE ON: SID glide (MEDIUM), Game Boy CC 5 = 32", c.v("glideK") == 4 and (10, 32) in gl and (12, 32) in gl, gl)
menu_set(c, 3, 2)                            # -> AS SOUND
check("GLIDE AS SOUND: FAT has none", c.v("glideK") == 0)

# DETUNE
c.press("q", ms=200)
f = [sid_freq(c, v) for v in range(3)]
check("FAT: SID voices detuned apart", f[1] > f[0] > f[2], f)
t0 = c.cpu.processorCycles
menu_set(c, 5, 2)                            # DETUNE -> OFF
f = [sid_freq(c, v) for v in range(3)]
det = [x for x in ccs(c, t0, 94) if x[0] in GB]
check("DETUNE OFF: the held SID notes retuned together, Game Boy CC 94 = 64", f[0] == f[1] == f[2] and (10, 64) in det
      and (11, 64) in det, (f, det))
c.set("uDet", 3)                             # HUGE
menu_set(c, 5, 2)                            # -> AS SOUND -> ON
f = [sid_freq(c, v) for v in range(3)]
check("DETUNE ON (HUGE): twice FAT's spread", c.v("detNow") == 16 and f[1] - f[0] > 0, (c.v("detNow"), f))
menu_set(c, 5, 2)                            # -> OFF -> AS SOUND
check("DETUNE AS SOUND", c.v("detNow") == 8)
c.set("uDet", 1)

# WIDE held
c.set("spaceAct", A_WIDE)
t0 = c.cpu.processorCycles
c.press("space", ms=100)
f = [sid_freq(c, v) for v in range(3)]
pan = [x for x in ccs(c, t0, 10) if x[0] in GB]
det = [x for x in ccs(c, t0, 94) if x[0] in GB]
check("WIDE held: SID detune 22, the held notes spread", c.v("detNow") == 22 and f[1] - f[2] > 0, (c.v("detNow"), f))
check("WIDE held: Game Boy pulses panned apart, detuned wider (64 -+ 16)", (10, 0) in pan and (11, 127) in pan
      and (10, 48) in det and (11, 80) in det, (pan, det))
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

# TREMOLO ON (FAT has none): the SID's volume moves
menu_set(c, 4, 1)
c.press("q", ms=50)
vol = []
for _ in range(30):
    c.run_ms(10)
    vol.append(c.raw[0xD418] & 15)
check("TREMOLO ON: the SID volume breathes", max(vol) == 15 and min(vol) < 10, vol)
menu_set(c, 4, 2)
c.run_ms(40)
check("TREMOLO AS SOUND: volume back to 15", c.raw[0xD418] & 15 == 15)
c.release("q", ms=60)

# MONO/POLY and WARBLE
t0 = c.cpu.processorCycles
menu_set(c, 0, 1)
check("MONO/POLY: MONO", c.v("monoLock") == 1 and c.v("monoMode") == 1)
c.tap("v", ms=300)
check("... kept on the next sound (PADS)", c.v("soundMode") == 1 and c.v("monoMode") == 1)
menu_set(c, 0, 2)
check("MONO/POLY: AS SOUND (PADS: poly)", c.v("monoLock") == 0 and c.v("monoMode") == 0)
t0 = c.cpu.processorCycles
menu_set(c, 6, 2)                            # WARBLE -> OFF
wb = [b for _, s, a, b in since(c, t0) if s == 0xBA and a == 104]
check("WARBLE OFF: Game Boy warble 0", wb[-1:] == [0], wb)
menu_set(c, 6, 1)
c.press("lshift", ms=10); c.tap("v", ms=300); c.release("lshift", ms=10)

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

# ---------------------------------------------------------------- visualizer
c.tap("f7", ms=150)
check("F7: the visualizer", c.v("vizOn") == 1 and "VISUALIZER" in c.screen_row(0) and "SID" in c.screen_row(23), c.screen_row(0))
c.press("q", ms=150)
col = [c.raw[0x0400 + r * 40 + 1] for r in range(2, 22)]
check("a note: SID 1's bar up (full blocks from the bottom)", col[-1] == 160 and col.count(160) >= 8, col)
check("... in C's colour (red)", c.raw[0xD800 + 21 * 40 + 1] & 15 == 2)
check("... its note under it", c.screen_row(22)[1:4] == "C 3", c.screen_row(22))
c.release("q", ms=1500)
col = [c.raw[0x0400 + r * 40 + 1] for r in range(2, 22)]
check("let go: the bar falls away", col.count(160) == 0, col)
c.tap("return", ms=60)
check("RETURN: the menu from the visualizer", c.v("menuOn") == 1 and "MENU" in c.screen_row(0))
c.tap("f7", ms=60)
check("F7 in the menu: nothing", c.v("vizOn") == 1 and c.v("menuOn") == 1)
c.press("lshift", ms=10); c.tap("return", ms=100); c.release("lshift", ms=100)
check("closing the menu: back to the visualizer", "VISUALIZER" in c.screen_row(0), c.screen_row(0))
c.tap("f7", ms=100)
c.tap("f7", ms=200)
check("F7 (GLITCH), F7: the play screen again", c.v("vizOn") == 0 and c.screen_row(4).startswith("SID") and c.raw[0xD800 + 4 * 40] & 15 == 13)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
