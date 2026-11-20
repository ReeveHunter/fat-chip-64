#!/usr/bin/env python3
"""Fat Chip 64 v0.51: One Key Play's notes sound in MONO (beside the mono
note, with their own attacks), Fat Bass never takes them (no chord: no Fat
Bass), and they never glide in with a chord change."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def vn(c):
    return [c.v("vNote", 9)[v] for v in range(9)]


def okp(c):
    return [n for n in c.v("okpNotes", 2) if n != 255]


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.51", "V0.51" in c.screen_row(0), c.screen_row(0))
c.set("okpOn", 1)

# MONO
c.set("playMode", 0)
c.set("monoMode", 1)
c.press("q", ms=200)
c._raw_press("crsrdown", ms=200)
o = okp(c)
v = vn(c)
check("MONO, a key held: One Key Play's notes sound beside the mono note", 48 in v and o and all(n in v for n in o), (o, v))
c._raw_release("crsrdown", ms=200)
check("... let go of the cursor key: just the mono note", set(n for n in vn(c) if n != 255) == {48}, vn(c))
c.release("q", ms=300)
c._raw_press("crsrdown", ms=200)
o = okp(c)
check("MONO, One Key Play alone: both its notes", o and set(n for n in vn(c) if n != 255) == set(o), (o, vn(c)))
c._raw_release("crsrdown", ms=300)
c.set("monoMode", 0)

# Fat Bass
c.set("fatBass", 1)
c.set("reallocFlag", 1)
c.run_ms(100)
c._raw_press("crsrdown", ms=200)
fat = [v for v in range(9) if c.v("vFat", 9)[v]]
check("FAT BASS, One Key Play alone: no Fat Bass voices", not fat, (fat, vn(c)))
c._raw_release("crsrdown", ms=300)
c.press("q", ms=200)
c._raw_press("crsrdown", ms=200)
fat = [v for v in range(9) if c.v("vFat", 9)[v]]
check("FAT BASS with a key held: the bass voices play the chord's note (48), not One Key Play's",
      fat and all(vn(c)[v] == 48 for v in fat), ([vn(c)[v] for v in fat], okp(c)))
c._raw_release("crsrdown", ms=200)
c.release("q", ms=300)
c.set("fatBass", 0)

# CHORD CHANGE: GLIDE. One Key Play held through chord changes: a voice that
# takes one of its notes never glides there (NES: no glide offset; SID: at its
# frequency straight away)
c.set("chgMode", 2)
c.set("playMode", 1)
c._raw_tap("l", ms=60)
c.press("q", ms=100)
c.release("q", ms=1200)
bad = []
moves = 0
for k in "tryeq":
    c._raw_press("crsrdown", ms=60)
    c.press(k, ms=0)
    prev = c.v("vNote", 9)
    for step in range(60):
        c.run_ms(2)
        now = c.v("vNote", 9)
        o = okp(c)
        ch = c.v("okpChord", 8)[:c.v("okpChordN")]
        for v in range(9):
            n = now[v]
            if n == prev[v] or n not in o or n in ch:   # (judged as it moves to a note that's One Key Play's alone)
                continue
            moves += 1
            if c.v("vDev", 9)[v] == 2 and (c.v("nesGlH", 9)[v] or c.v("nesGlL", 9)[v]):
                bad.append((k, step, "NES", v, n))
        prev = now
    c.release(k, ms=200)
    c._raw_release("crsrdown", ms=1200)                     # (past SMART latch's window: a new chord next)
check("chord changes with One Key Play held (CHORD CHANGE GLIDE): a voice moving to its notes never glides", not bad and moves > 0, (bad[:5], moves))
nes_gl = 0
c.press("y", ms=0)
for _ in range(10):
    c.run_ms(4)
    nes_gl += sum(1 for v in (2, 5, 8) if c.v("nesGlH", 9)[v] or c.v("nesGlL", 9)[v])
check("... the chord itself still glides (NES)", nes_gl > 0, nes_gl)
c.release("y", ms=300)
c._raw_tap("l", ms=60)
c.set("chgMode", 0)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
