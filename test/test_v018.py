#!/usr/bin/env python3
"""Fat Chip 64 v0.18: the live patch. Every sound setting is read from one
block in RAM (livePatch); choosing a built-in patch copies it in whole."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0
ROOT = os.path.join(os.path.dirname(__file__), "..")


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


c = C64(channels=None)
c.run_ms(400)
check("header V0.29", "V0.29" in c.screen_row(0), c.screen_row(0))
size = c.sym["PATCH_SIZE"] if "PATCH_SIZE" in c.sym else None
n = c.sym.get("NUM_SOUNDS", 19)
names = [l.split('"')[1].rstrip() for l in open(os.path.join(ROOT, "src", "soundtab.asm")) if l.startswith('        .byte "')]
check("19 built-in patches", len(names) == 19, len(names))
check("at start: FAT in the live patch", c.v("livePatch", size) == c.v("patch0", size))

ok = []
for i in range(len(names)):
    c.midi_in(0xC0, i, ms=150)
    ok.append(c.v("livePatch", size) == c.v(f"patch{i}", size) and names[i] in c.screen_row(2))
check("each patch (program change 0-18) copied in whole, its name on screen", all(ok),
      [names[i] for i, k in enumerate(ok) if not k])

# the sound plays from the live patch: change the filter cutoff in it
c.midi_in(0xC0, 1, ms=200)                      # PADS: filtered
c.press("q", ms=200)
before = c.raw[0xD416]
c.set("sndCut", 0xC0)
c.set("sndFDep", 0)
c.run_ms(100)
check("a changed cutoff in the live patch is heard at once", c.raw[0xD416] >= 0xC0 and before < 0x80,
      (hex(before), hex(c.raw[0xD416])))
c.release("q", ms=200)
c.midi_in(0xC0, 0, ms=200)
c.midi_in(0xC0, 1, ms=200)
c.press("q", ms=200)
check("choosing it again (after another) restores it", c.v("livePatch", size) == c.v("patch1", size) and c.raw[0xD416] < 0x80)
c.release("q", ms=100)

# RAW's own widths now come from the patch, not from its number
c.midi_in(0xC0, 2, ms=200)
c.press("q", "e", "t", ms=200)
check("RAW: the SID voices 50 / 25 / 12.5 %", [c.raw[0xD403 + 7 * v] for v in range(3)] == [8, 4, 2],
      [c.raw[0xD403 + 7 * v] for v in range(3)])
c.release("q", "e", "t", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
