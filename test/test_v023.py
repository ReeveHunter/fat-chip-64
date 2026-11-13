#!/usr/bin/env python3
"""Fat Chip 64 v0.23: Chip Lab's chip buttons. F0 7D 46 43 02 m F7 turns the
SID (bit 0), Game Boy (bit 1) and NES (bit 2) on or off."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def chips(c, m, ms=150):
    c.midi_in(0xF0, 0x7D, 0x46, 0x43, 0x02, m, 0xF7, ms=ms)


c = C64(channels=None)
c.run_ms(400)
check("header V0.28", "V0.28" in c.screen_row(0), c.screen_row(0))
check("all three on at start", c.v("devOn", 3) == [1, 1, 1])
chips(c, 0b110)
check("m = 6: the SID off, Game Boy and NES on", c.v("devOn", 3) == [0, 1, 1], c.v("devOn", 3))
c.press("q", ms=200)
check("... a note: no SID (volume 0), the Game Boy and NES play", c.raw[0xD418] & 15 == 0 and c.v("vWant", 9)[1] != 255)
c.release("q", ms=900)
chips(c, 0b001)
check("m = 1: only the SID", c.v("devOn", 3) == [1, 0, 0], c.v("devOn", 3))
chips(c, 0b001)
check("the same again: nothing changes", c.v("devOn", 3) == [1, 0, 0])
c.midi_in(0xF0, 0x7D, 0x46, 0x43, 0x02, 7, 0, 0xF7, ms=150)
check("one byte too many: ignored", c.v("devOn", 3) == [1, 0, 0])
c.midi_in(0xF0, 0x7D, 0x46, 0x43, 0x02, 0xF7, ms=150)
check("no byte: ignored", c.v("devOn", 3) == [1, 0, 0])
chips(c, 7, ms=400)
check("m = 7: all on again", c.v("devOn", 3) == [1, 1, 1])
p = copy.deepcopy(gen_patches.PATCHES[1]); p["name"] = "AFTER CHIPS"
c.midi_in(*gen_patches.sysex(p), ms=200)
check("a patch still arrives after a chips message", "AFTER CHIPS" in c.screen_row(2), c.screen_row(2))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
