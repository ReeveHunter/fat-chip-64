#!/usr/bin/env python3
"""Fat Chip 64 v0.28: CHORD + LEAD (LOW NOTE, LATCH 3), the lead's own patch
on its own voices (one per chip, only while it plays), SHIFT + bank / slot
keys pick it; the visualizer is GLITCH only."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0
LEAD_V = (1, 2, 6)                 # GB pulse 1, NES pulse 1, SID 3


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def rows(c):
    return [c.screen_row(r) for r in range(25)]


def sel(c, label):
    for _ in range(30):
        if any(r.startswith("> " + label) for r in rows(c)):
            return True
        c.tap("crsrdown", ms=25)
    return False


def row_of(c, label):
    return next((r for r in rows(c) if r[2:].startswith(label)), "")


def back(c, n=1):
    c._raw_press("lshift", ms=8)
    for _ in range(n):
        c._raw_tap("return", ms=50)
    c._raw_release("lshift", ms=40)


def set_cl(c, steps):
    c.tap("return", ms=60)
    sel(c, "PLAYING")
    c.tap("return", ms=60)
    sel(c, "SPLIT (C= V)")
    for _ in range(steps):
        c.tap("f7", ms=40)
    v = row_of(c, "SPLIT (C= V)")
    back(c, 2)
    return v


def held(c):
    return c.v("heldList", 8)[:c.v("heldCount")]


def shift(c, key, ms=150):
    c._raw_press("lshift", ms=10)
    c._raw_tap(key, ms=ms)
    c._raw_release("lshift", ms=40)


c = C64(channels=None)
c.run_ms(400)
check("header V0.32", "V0.32" in c.screen_row(0), c.screen_row(0))
check("row 3 empty with CHORD + LEAD off", c.screen_row(3).strip() == "", c.screen_row(3))

# ---------------------------------------------------------------- LOW NOTE
v = set_cl(c, 2)
check("PLAYING: SPLIT LOW NOTE (v0.32: after KEY)", "LOW NOTE" in v and c.v("clMode") == 2, v)
c.run_ms(200)
check("row 3: the lead's patch (LEADS 1: DUTY LEAD)", c.screen_row(3).startswith("LEAD    DUTY LEAD"), c.screen_row(3))
sid3_chord = c.raw[0xD400 + 14 + 4] & 0xF0
c.press("q", ms=150)
check("the first key: the chord (POLY: just it, v0.29)", held(c) == [48] and c.v("leadNote") == 255, held(c))
check("... on every voice (no lead playing)", all(n != 255 for n in c.v("vNote", 9)), c.v("vNote", 9))
t0 = c.cpu.processorCycles
c.press("e", ms=150)
vn = c.v("vNote", 9)
check("another key: the lead (E), on SID 3, GB pulse 1, NES pulse 1", c.v("leadNote") == 52
      and all(vn[i] == 52 for i in LEAD_V) and c.v("vLead", 9) == [0, 1, 1, 0, 0, 0, 1, 0, 0], vn)
check("... the chord keeps the other six voices", sorted(set(vn[i] for i in range(9) if i not in LEAD_V)) == [48], vn)
lead_wave = c.v("leadPatch", 128)[8] & 0xF0
check("... SID 3 has the lead's waveform", c.raw[0xD400 + 14 + 4] & 0xF0 == lead_wave, (hex(c.raw[0xD412]), hex(lead_wave)))
ccs = [(s, a, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 70]
gbd = c.v("leadPatch", 128)[35]
check("... the Game Boy's pulse 1 gets the lead's duty (CC 70)", any(b == gbd for s, a, b in ccs), (ccs, gbd))
check("... vPat: the lead's patch on its channels", [c.v("vPat", 9)[i] for i in LEAD_V] == [1, 1, 1])
c.press("t", ms=150)
check("a second lead key: the last one pressed (G)", c.v("leadNote") == 55)
c.release("t", ms=80)
check("... let go: the lead goes back to... nothing (E's key: still down? no: last pressed only)", c.v("leadNote") in (255, 52))
c.release("e", ms=150)
vn = c.v("vNote", 9)
check("lead let go: its voices go back to the chord", c.v("leadNote") == 255 and all(n == 48 for n in vn), vn)
check("... with the chord's patch again (SID 3's waveform)", c.raw[0xD412] & 0xF0 == sid3_chord and c.v("vPat", 9)[6] == 0,
      hex(c.raw[0xD412]))
c.release("q", ms=150)
c.press("t", ms=120)
check("chord key let go, the next key's the new chord (G)", held(c) == [55], held(c))
c.release("t", ms=150)
c._raw_press("cbm", ms=30); c._raw_tap("z", ms=30); c._raw_release("cbm", ms=30)
c.press("q", ms=120)
check("SMART CHORD (TRIAD): the chord key holds its triad (C E G)", held(c) == [48, 52, 55], held(c))
c.press("u", ms=120)
check("... and the lead plays over it (B)", c.v("leadNote") == 59 and held(c) == [48, 52, 55])
c.release("u", "q", ms=150)
c._raw_press("cbm", ms=30); c._raw_tap("x", ms=30); c._raw_tap("x", ms=30); c._raw_tap("x", ms=30)
c._raw_tap("x", ms=30); c._raw_release("cbm", ms=30)
c.press("q", ms=120)
check("SMART 5TH: C G", held(c) == [48, 55], held(c))
c.release("q", ms=100)
c._raw_press("cbm", ms=30); c._raw_tap("x", ms=30); c._raw_tap("z", ms=30); c._raw_tap("z", ms=30)
c._raw_release("cbm", ms=30)
check("(back to TRIAD, POLY)", c.v("spice") == 1 and c.v("playMode") == 0)
c.press("t", ms=120)
c.release("t", ms=150)

# ---------------------------------------------------------------- the arp plays the chord, never the lead
c._raw_press("cbm", ms=30); c._raw_tap("z", ms=30); c._raw_release("cbm", ms=30)   # SMART CHORD
c._raw_tap("f5", ms=60)                      # arp on (UNISON)
c.press("q", ms=300)
c.press("e", ms=50)
t0 = c.cpu.processorCycles
c.run_ms(900)
gb1 = [(a, b) for t, s, a, b in c.midi() if t >= t0 and s == 0x90 + c.v("gbBase")]
arp = [a for t, s, a, b in c.midi() if t >= t0 and s == 0x90 + c.v("gbBase") + 1 and b]
check("arp UNISON: the chord voices step through C E G", set(arp) <= {48, 52, 55} and len(set(arp)) == 3, arp[:8])
check("... the lead's voice holds its note (no new attacks from the arp)", gb1 == [] and c.v("vNote", 9)[1] == 52, gb1[:4])
c._raw_press("cbm", ms=30); c._raw_tap("a", ms=30); c._raw_release("cbm", ms=30)   # SPARKLE
c.run_ms(500)
vn = c.v("vNote", 9)
check("arp SPARKLE: its pair is SID 2 + GB pulse 2, the lead keeps SID 3 / GB 1 / NES 1",
      c.v("pairA") == 3 and c.v("pairB") == 4 and all(vn[i] == 52 for i in LEAD_V), (c.v("pairA"), c.v("pairB"), vn))
c.release("e", "q", ms=100)
c._raw_press("cbm", ms=30); c._raw_tap("a", ms=30); c._raw_release("cbm", ms=30)   # back to UNISON
c._raw_tap("f5", ms=60)                      # arp off
c._raw_press("cbm", ms=30); c._raw_tap("z", ms=30); c._raw_tap("z", ms=30); c._raw_release("cbm", ms=60)  # POLY
c.run_ms(800)

# ---------------------------------------------------------------- the lead's patch
shift(c, "g")
check("SHIFT + G: the lead's bank FX (FX 1, ECHO PLUCK); the chord's patch stays",
      c.screen_row(3).startswith("LEAD    ECHO PLUCK") and c.screen_row(2).startswith("FAT"), (c.screen_row(2), c.screen_row(3)))
shift(c, "x")
check("SHIFT + X: FX 2 (ELECTRIC PIANO)", c.screen_row(3).startswith("LEAD    ELECTRIC PIANO"), c.screen_row(3))
shift(c, "d")
shift(c, "z")
check("SHIFT + D, SHIFT + Z: back to DUTY LEAD", c.screen_row(3).startswith("LEAD    DUTY LEAD"), c.screen_row(3))

# ---------------------------------------------------------------- LATCH 3
v = set_cl(c, 1)
check("SPLIT: LATCH 3", "LATCH 3" in v and c.v("clMode") == 3, v)
c.press("q", "e", "t", ms=100)
c.release("q", "e", "t", ms=150)
check("three keys together: latched as the chord (C E G), keeps sounding", held(c) == [48, 52, 55]
      and c.v("leadNote") == 255, held(c))
c.press("u", ms=120)
check("one key: the lead over it (B)", c.v("leadNote") == 59 and held(c) == [48, 52, 55], (c.v("leadNote"), held(c)))
c.release("u", ms=60)
c.press("w", ms=60); c.release("w", ms=60)
c.press("r", ms=60)
check("... and another (lead notes one at a time, never the chord)", c.v("leadNote") == 53 and held(c) == [48, 52, 55])
c.release("r", ms=100)
c.press("w", "r", "y", ms=100)
c.release("w", "r", "y", ms=150)
check("three more together: the new chord (D F A)", held(c) == [50, 53, 57], held(c))
c.tap("l", ms=150)
check("L: the chord let go", held(c) == [] and c.v("clChordN") == 0, held(c))

# ---------------------------------------------------------------- off again
v = set_cl(c, 1)
c.run_ms(200)
check("CHORD + LEAD OFF: row 3 empty, keys play as before", "OFF" in v and c.screen_row(3).strip() == "", c.screen_row(3))
c.press("q", "e", ms=120)
check("... POLY: both notes", held(c) == [48, 52] and c.v("vLead", 9) == [0] * 9, held(c))
c.release("q", "e", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
