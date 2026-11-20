#!/usr/bin/env python3
"""Fat Chip 64 v0.44: F5 is on / off and F7 the cycle in every layer (SHIFT:
SPLIT on / off, its mode); C= + F1 / F3 arp octave up / down; SMART CHORD's
size shown dark grey in POLY and MONO; One Key Play shares the lead's
octave (SHIFT + F1 / F3)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
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
c.keys_039 = False
c.fkeys_036 = False
c.menu_fkeys = False
c.run_ms(400)
check("header V0.47", "V0.47" in c.screen_row(0), c.screen_row(0))

mod(c, "lshift", "f5")
check("SHIFT + F5: SPLIT on (KEY)", c.v("clMode") == 1, c.v("clMode"))
mod(c, "lshift", "f7")
check("SHIFT + F7: its next mode (BASS)", c.v("clMode") == 2, c.v("clMode"))
mod(c, "lshift", "f5")
check("SHIFT + F5: off", c.v("clMode") == 0, c.v("clMode"))

c.set("arpOct", 0)
mod(c, "cbm", "f1")
check("C= + F1: arp octave up", c.v("arpOct") == 1, c.v("arpOct"))
mod(c, "cbm", "f3")
check("C= + F3: down", c.v("arpOct") == 0, c.v("arpOct"))

# row 9: SMART CHORD's size, dark grey unless SMART CHORD
c.set("playMode", 0)
c.set("screenDirty", 1)
c.run_ms(200)
row = c.screen_row(9)
col = c.raw[0xD800 + 9 * 40 + 18] & 15
check("POLY: row 9 shows SMART's size, dark grey", row[18:27].startswith("SMART") and col == 11, (row, col))
c._raw_tap("n", ms=60)
c.run_ms(200)
check("... N changes it (still dark grey)", c.screen_row(9)[18:28] != row[18:28] and c.raw[0xD800 + 9 * 40 + 18] & 15 == 11,
      c.screen_row(9))
c._raw_tap("f7", ms=60)                                      # POLY -> SMART CHORD (v0.47)
c.run_ms(200)
check("SMART CHORD: the same text, light green", c.v("playMode") == 1 and c.raw[0xD800 + 9 * 40 + 18] & 15 == 13,
      (c.v("playMode"), c.raw[0xD800 + 9 * 40 + 18] & 15))
c._raw_tap("f7", ms=60)
c._raw_tap("f7", ms=60)                                      # -> MONO -> POLY

# One Key Play in the lead's octave
c.set("okpOn", 1)
c.set("leadOct", 3)                                          # +1 (the usual)
def okp_ofs():
    c._raw_press("crsrdown", ms=80)
    d = c.v("okpNotes") - c.v("okpList", 32)[c.v("okpPos")]
    c._raw_release("crsrdown", ms=200)
    return d


d0 = okp_ofs()
mod(c, "lshift", "f1")
check("SHIFT + F1: LEAD +2 (shared)", c.v("leadOct") == 4)
d1 = okp_ofs()
check("LEAD +1 (the usual): One Key Play's notes where they always were; LEAD +2: an octave up", d0 == 0 and d1 == 12, (d0, d1))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
