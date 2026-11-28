#!/usr/bin/env python3
"""Fat Chip 64 v0.52: One Key Play's notes get voices of their own (vOkp),
even when the chord has the same note, and keep them while they sound: a
chord change doesn't glide, move or re-attack them, the arp never hits them,
and a chord key doesn't re-attack them. (No more status every 2 s:
test_v050.)"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def okpv(c):
    return {v: c.v("vNote", 9)[v] for v in range(9) if c.v("vOkp", 9)[v]}


def chan(c, v):
    d = c.v("vDev", 9)[v]
    return None if d == 0 else (c.v("gbBase") if d == 1 else c.v("nesBase")) + c.v("vIdx", 9)[v]


def ons(c, t0, chs):
    return [(s & 15, a) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0x90 and b and (s & 15) in chs]


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.69", "V0.69" in c.screen_row(0), c.screen_row(0))
c.set("okpOn", 1)
c.set("okpSrc", 1)                                           # CHORD NOTES: its notes are the chord's
c.set("leadOct", 2)                                          # (LEAD 0: in the chord's octave)
c.set("playMode", 1)
c.set("chgMode", 2)                                          # CHORD CHANGE: GLIDE
c._raw_tap("l", ms=60)
c.press("q", ms=100)
c.release("q", ms=1200)
c._raw_press("crsrdown", ms=150)
o = [n for n in c.v("okpNotes", 2) if n != 255]
chord = c.v("okpChord", 8)[:c.v("okpChordN")]
ov = okpv(c)
check("CHORD NOTES: One Key Play's notes are chord notes too", o and all(n in chord for n in o), (o, chord))
check("... yet they have voices of their own", sorted(ov.values()) == sorted(o) or set(ov.values()) == set(o), (ov, o))
chord_voices = [c.v("vNote", 9)[v] for v in range(9) if not c.v("vOkp", 9)[v] and c.v("vNote", 9)[v] != 255]
check("... and the chord keeps all its notes on the other voices", all(n in chord_voices for n in chord), (chord, chord_voices))

# a chord change (GLIDE) while it's held
chs = [ch for ch in (chan(c, v) for v in ov) if ch is not None]
t0 = c.cpu.processorCycles
c.press("t", ms=0)
moved = []
for _ in range(100):
    c.run_ms(4)
    now = okpv(c)
    if any(now.get(v) != n for v, n in ov.items()):
        moved.append(now)
    for v in ov:
        if c.v("vDev", 9)[v] == 2 and (c.v("nesGlH", 9)[v] or c.v("nesGlL", 9)[v]):
            moved.append(("glide", v))
check("chord change (GLIDE) with One Key Play held: its voices keep their notes, no glide", not moved, moved[:3])
check("... and aren't played again", not ons(c, t0, chs), ons(c, t0, chs))
c.release("t", ms=200)
c._raw_release("crsrdown", ms=1200)

# a chord key that has One Key Play's note: no re-attack of its voice
c._raw_press("crsrdown", ms=150)
ov = okpv(c)
chs = [ch for ch in (chan(c, v) for v in ov) if ch is not None]
t0 = c.cpu.processorCycles
c.press("q", ms=300)
check("a chord key with One Key Play's note: its voice isn't attacked again", not ons(c, t0, chs) and okpv(c) == ov, (ons(c, t0, chs), ov, okpv(c)))
c.release("q", ms=200)
c._raw_release("crsrdown", ms=1200)
c._raw_tap("l", ms=60)
c.set("chgMode", 0)
c.run_ms(300)

# the arp (UNISON) never hits One Key Play's voices, even on a shared note
c.set("arpMode", 1)
c.press("q", ms=100)
c._raw_press("crsrdown", ms=60)
ov = okpv(c)
chs = [ch for ch in (chan(c, v) for v in ov) if ch is not None]
t0 = c.cpu.processorCycles
hit = 0
for _ in range(150):
    c.run_ms(10)
    hit += sum(c.v("vArpHit", 9)[v] for v in range(9) if c.v("vOkp", 9)[v])
check("arp UNISON: One Key Play's voices never get an arp hit", hit == 0 and ov, (hit, ov))
check("... nor a new note-on while held", not ons(c, t0, chs), ons(c, t0, chs)[:4])
c._raw_release("crsrdown", ms=60)
c.release("q", ms=300)
c.set("arpMode", 0)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
