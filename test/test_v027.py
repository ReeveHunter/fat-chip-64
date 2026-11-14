#!/usr/bin/env python3
"""Fat Chip 64 v0.27: FINE TUNE (every chip; finer NES bends), CHORD CHANGE
(ATTACK / GLIDE / SPLIT / WANDER), DRONE, One Key Play."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


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


def open_page(c, page):
    c.tap("return", ms=60)
    sel(c, page)
    c.tap("return", ms=60)


def sid_f(c, v=0):
    return c.raw[0xD400 + 7 * v] | c.raw[0xD401 + 7 * v] << 8


def held(c):
    return c.v("heldList", 8)[:c.v("heldCount")]


def since(c, t0):
    return [(s, a, b) for t, s, a, b in c.midi() if t >= t0]


c = C64(channels=None)
c.run_ms(400)
check("header V0.35", "V0.35" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- FINE TUNE
c.midi_in(0x90, 60, 100, ms=80)
f0 = sid_f(c)
open_page(c, "PLAYING")
check("PLAYING: FINE TUNE 0 CENTS, CHORD CHANGE AS MODE, WANDER TIME 3 S, DRONE VOICING FIFTHS",
      "0 CENTS" in row_of(c, "FINE TUNE") and "AS MODE" in row_of(c, "CHORD CHANGE") and "3 S" in row_of(c, "WANDER TIME")
      and "FIFTHS" in row_of(c, "DRONE VOICING"), rows(c)[2:13])
sel(c, "FINE TUNE")
t0 = c.cpu.processorCycles
for _ in range(20):
    c.tap("f7", ms=30)
c.run_ms(100)
f1 = sid_f(c)
ccs = [b for s, a, b in since(c, t0) if s & 0xF0 == 0xB0 and a == 103]
check("F7 x 20: +20 CENTS", "+20 CENTS" in row_of(c, "FINE TUNE") and c.v("tuneC") == 20, row_of(c, "FINE TUNE"))
check("... the held SID note moves at once, 20 cents up", abs(f1 / f0 - 2 ** (20 / 1200)) < 0.0006, (f0, f1))
check("... the Game Boy's master tune 64 + 26 (0.78 cents a step)", ccs and ccs[-1] == 90, ccs[-3:])
check("... the NES: 13/64 semitone", c.v("tuneN") == 13, c.v("tuneN"))
for _ in range(60):
    c.tap("f5", ms=30)
c.run_ms(100)
check("F5 x 60: -40 CENTS (and the SID 40 cents flat)", "-40 CENTS" in row_of(c, "FINE TUNE")
      and abs(sid_f(c) / f0 - 2 ** (-40 / 1200)) < 0.0006 and c.v("tuneN") == (256 - 26), (row_of(c, "FINE TUNE"), c.v("tuneN")))
back(c, 2)
c.midi_in(0x80, 60, 0, ms=200)
# the NES: in 1/64 semitones now (finer bends): -40 cents = -26, FAT's detune -4 / +4
c.midi_in(0x90, 60, 100, ms=150)
tl = c.v("nesTotL", 9)
check("NES pulses: bent for -40 cents and FAT's detune, in 1/64 semitones", tl[2] == 256 - 30 and tl[5] == 256 - 22, tl)
c.midi_in(0x80, 60, 0, ms=200)
c.set("fineTune", 50)
open_page(c, "PLAYING"); sel(c, "FINE TUNE"); c.tap("f7", ms=30); c.tap("f5", ms=60)
back(c, 2)
check("back to 0", c.v("tuneC") == 0 and c.v("tuneN") == 0)

# ---------------------------------------------------------------- DRONE
for _ in range(2):
    c._raw_press("cbm", ms=30); c._raw_tap("z", ms=30); c._raw_release("cbm", ms=30)
check("C= + Z x 2: DRONE (v0.29)", c.v("playMode") == 2 and "DRONE" in c.screen_row(9), c.screen_row(9))
c.press("q", ms=120)
check("a key: open fifths up from it (C: C G C G)", held(c) == [48, 55, 60, 67], held(c))
check("CHORD CHANGE AS MODE in DRONE: glides (glideK set)", c.v("glideK") > 0, c.v("glideK"))
c.release("q", ms=50)
c.tap("l", ms=40)                            # latch SMART
c.tap("q", ms=1500)
before = list(c.v("vNote", 9))
c.tap("t", ms=150)                           # G: the drone moves... slowly
want = list(c.v("vWant", 9))
now = list(c.v("vNote", 9))
check("a new key: the voices want the new notes (G D G D)", set(w for w in want if w != 255) <= {55, 62, 67, 74}, want)
check("... but WANDER: not all have moved yet", now != want, (now, want))
c.run_ms(3500)
check("... within WANDER TIME (3 s) all of them are there", list(c.v("vNote", 9)) == list(c.v("vWant", 9)),
      (list(c.v("vNote", 9)), list(c.v("vWant", 9))))
open_page(c, "PLAYING"); sel(c, "DRONE VOICING"); c.tap("f7", ms=60)
back(c, 2)
c.tap("q", ms=200)
check("DRONE VOICING FIFTHS + 9TH: C G C D G", held(c) == [48, 55, 60, 62, 67], held(c))
c.tap("l", ms=40)                            # latch off
c.run_ms(4000)
for _ in range(1):
    c._raw_press("cbm", ms=30); c._raw_tap("z", ms=30); c._raw_release("cbm", ms=30)
check("C= + Z: back to POLY", c.v("playMode") == 0)
c.set("droneVc", 0)

# ---------------------------------------------------------------- CHORD CHANGE GLIDE / SPLIT / ATTACK
open_page(c, "PLAYING"); sel(c, "CHORD CHANGE"); c.tap("f7", ms=30); c.tap("f7", ms=60)
check("CHORD CHANGE: GLIDE", "GLIDE" in row_of(c, "CHORD CHANGE") and c.v("glideK") > 0)
back(c, 2)
c.press("q", ms=1500)
fa = sid_f(c)
c.press("t", ms=300)
c.release("q", ms=30)                        # (SID 1 moves from C to G)
fm = sid_f(c)
c.run_ms(1500)
fb = sid_f(c)
check("GLIDE: the SID slides from C to G (half way after 30 ms: between)", fa < fm < fb and abs(fb / fa - 1.4983) < 0.01,
      (fa, fm, fb))
c.release("t", ms=1500)
c.set("chgMode", 1)
c.press("q", ms=1500)
fa = sid_f(c)
c.press("t", ms=300)
c.release("q", ms=30)
check("ATTACK: there at once", abs(sid_f(c) / fa - 1.4983) < 0.01, sid_f(c))
c.release("t", ms=1500)

# ---------------------------------------------------------------- One Key Play
open_page(c, "ONE KEY PLAY")
check("ONE KEY PLAY page: ON, PENTATONIC PAIRS, PING PONG, SOME, DOWN, CUTS",
      "ON" in row_of(c, "ONE KEY PLAY") and "PENTATONIC PAIRS" in row_of(c, "NOTES") and "PING PONG" in row_of(c, "MOTION")
      and "SOME" in row_of(c, "TURN") and "DOWN" in row_of(c, "DIRECTION") and "CUTS" in row_of(c, "EACH PRESS"), rows(c)[1:10])
back(c, 2)
pent = [48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72]
c._raw_press("crsrdown", ms=60)
check("CRSR DOWN: the top pentatonic pair (G + C)", held(c) == [67, 72], held(c))
c._raw_release("crsrdown", ms=60)
check("let go: silent", held(c) == [], held(c))
steps = []
for i in range(30):
    k = "crsrdown" if i % 2 == 0 else "crsrright"
    c._raw_press(k, ms=45)                   # (a quick press; a busy MIDI link can hold a pass up ~36 ms)
    steps.append(tuple(held(c)))
    c._raw_release(k, ms=10)
ok = all(len(s) == 2 and s[0] in pent and s[1] in pent and pent.index(s[1]) == pent.index(s[0]) + 2 for s in steps)
check("both cursor keys step on: always a pentatonic pair one note apart", ok, steps[:6])
moves = [pent.index(b[0]) - pent.index(a[0]) for a, b in zip(steps, steps[1:])]
check("PING PONG: one step at a time, both ways", all(abs(m) == 1 for m in moves) and 1 in moves and -1 in moves, moves)
c._raw_press("crsrdown", ms=20)
c._raw_press("crsrright", ms=20)
c._raw_release("crsrdown", ms=20)
check("rolling fingers: the newest pair sounds while the other key's down", len(held(c)) == 2)
c._raw_release("crsrright", ms=40)
c.set("okpRing", 1)
c._raw_press("crsrdown", ms=20)
c._raw_press("crsrright", ms=20)
c._raw_release("crsrdown", ms=20)
check("RINGS ON: the last pair rings under the new one (4 notes)", len(held(c)) == 4, held(c))
c._raw_release("crsrright", ms=40)
c.set("okpRing", 0)
c.press("k", ms=20); c.press("e", "t", ms=30); c.release("e", "t", ms=30); c.release("k", ms=60)   # E minor (E + G)
c._raw_press("crsrdown", ms=40)
minor = held(c)
c._raw_release("crsrdown", ms=40)
check("in a minor key: the minor pentatonic (E G A B D)", all((n - 52) % 12 in (0, 3, 5, 7, 10) for n in minor), minor)
c.press("k", ms=20); c.tap("q", ms=30); c.release("k", ms=60)
open_page(c, "ONE KEY PLAY"); sel(c, "NOTES"); c.tap("f7", ms=60)
back(c, 2)
c.tap("l", ms=40)
c.press("q", "e", "t", ms=60); c.release("q", "e", "t", ms=60)   # a latched C chord
c._raw_press("crsrdown", ms=40)
h = held(c)
c._raw_release("crsrdown", ms=40)
check("CHORD NOTES: one note of the chord (over two octaves) on top of it", len(h) == 4 and h[:3] == [48, 52, 55]
      and h[3] in (48, 52, 55, 60, 64, 67), h)
c.tap("l", ms=60)
open_page(c, "ONE KEY PLAY"); sel(c, "ONE KEY PLAY"); c.tap("f7", ms=60)
back(c, 2)
c._raw_press("crsrdown", ms=40)
check("ONE KEY PLAY OFF: the cursor keys play nothing", held(c) == [], held(c))
c._raw_release("crsrdown", ms=40)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
