#!/usr/bin/env python3
"""Fat Chip 64 v0.15: VINYL STOP stops, OCTAVE UP moves everything, the
GLITCH visualizer, MidiNES vibrato / glide / detune by pitch bend."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0
A_VINYL, A_OCTUP, A_WIDE = 7, 10, 15
NES = (0, 1, 2)


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def since(c, t0):
    return [(t, s, a, b) for t, s, a, b in c.midi(since=t0)]


def bends(c, t0, chs=NES):
    return [(s & 15, (b << 7 | a) - 8192) for _, s, a, b in since(c, t0) if s & 0xF0 == 0xE0 and (s & 15) in chs]


def ons(c, t0):
    return [(s & 15, a) for _, s, a, b in since(c, t0) if s & 0xF0 == 0x90 and b]


c = C64(channels=None)
c.run_ms(400)
check("header V0.34", "V0.34" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- OCTAVE UP
c.set("spaceAct", A_OCTUP)
c.press("q", ms=150)
f0 = c.sid(0)[0]
t0 = c.cpu.processorCycles
c.press("space", ms=150)
on = ons(c, t0)
check("OCTAVE UP held: the overlay note moves up (Game Boy and NES C4)", (10, 60) in on and (0, 60) in on, on)
check("... the SID too", abs(c.sid(0)[0] - 2 * f0) < 20, (f0, c.sid(0)[0]))
check("... held list shows C 4", "C 4" in c.screen_row(15), c.screen_row(15))
t0 = c.cpu.processorCycles
c.release("space", ms=150)
check("let go: back to C3", (10, 48) in ons(c, t0) and abs(c.sid(0)[0] - f0) < 10)
c.release("q", ms=100)
c.midi_in(0x90, 62, 100, ms=100)
c.press("space", ms=150)
check("OCTAVE UP: a MIDI-in note too (D4 -> D5)", 74 in c.v("heldList", 8)[:c.v("heldCount")], c.v("heldList", 4))
c.release("space", ms=100)
c.midi_in(0x80, 62, 0, ms=150)

# ---------------------------------------------------------------- VINYL STOP
c.set("spaceAct", A_VINYL)
c.tap("f5", ms=300)
c.press("q", ms=150)
f0 = c.sid(0)[0]
c.press("space", ms=500)
check("VINYL STOP half way: pitch down, still sounding", c.sid(0)[0] < f0 * 0.8 and c.raw[0xD418] & 15 == 15, (f0, c.sid(0)[0]))
c.run_ms(700)
check("... the SID two octaves down, fading", abs(c.sid(0)[0] - f0 / 4) < 8 and c.raw[0xD418] & 15 < 15,
      (c.sid(0)[0], c.raw[0xD418] & 15))
c.run_ms(400)
t0 = c.cpu.processorCycles
c.run_ms(800)
m = since(c, t0)
check("stopped: silent (SID volume 0), no drums, no notes",
      c.v("vinylCut") == 1 and c.raw[0xD418] & 15 == 0 and not [1 for _, s, a, b in m if s & 0xF0 == 0x90 and b], m[:6])
check("... the Game Boy and NES notes cut (note-offs sent)", c.v("muteNow") == 1)
t0 = c.cpu.processorCycles
c.release("space", ms=700)
on = ons(c, t0)
check("let go: winds back up, notes and drums back", c.v("vinylLvl") == 0 and abs(c.sid(0)[0] - f0) < 4
      and c.raw[0xD418] & 15 == 15 and (10, 48) in on and [1 for ch, a in on if ch in (3, 4)], on[:10])
c.release("q", ms=100)
c.tap("f5", ms=150)

# ---------------------------------------------------------------- MidiNES effects
t0 = c.cpu.processorCycles
c.press("q", ms=200)
tl = c.v("nesTotL", 9)
check("NES detune (FAT): pulse 1 bent down, pulse 2 up (sent once, kept)", tl[2] == 252 and tl[5] == 4, tl)   # (v0.27: 1/64 semitones)
c.release("q", ms=100)
t0 = c.cpu.processorCycles
c.press("q", ms=200)
check("... the next note: no new bend needed", bends(c, t0) == [], bends(c, t0))
c.set("spaceAct", A_WIDE)
t0 = c.cpu.processorCycles
c.press("space", ms=150)
b = bends(c, t0)
check("WIDE: the NES pulses further apart", any(ch == 0 and v < -12 for ch, v in b) and any(ch == 1 and v > 12 for ch, v in b), b)
c.release("space", ms=150)
c.release("q", ms=150)

c.midi_in(0xC0, 4, ms=300)                     # WHISTLE: vibrato
t0 = c.cpu.processorCycles
c.press("q", ms=1200)
b = bends(c, t0)
p1 = [v for ch, v in b if ch == 0]
check("NES vibrato (WHISTLE): pulse 1 bends up and down", len(p1) > 8 and min(p1) < -20 and max(p1) > 20, (len(p1), min(p1), max(p1)))
check("... not the triangle", not [1 for ch, v in b if ch == 2 and v])
gaps = [(b2[0] - b1[0]) / CYCLES_PER_MS for b1, b2 in zip(
    [x for x in since(c, t0) if x[1] == 0xE0], [x for x in since(c, t0) if x[1] == 0xE0][1:])]
check("... at most every 24 ms", gaps and min(gaps) >= 20, round(min(gaps), 1) if gaps else gaps)
c.release("q", ms=200)

c.midi_in(0xC0, 13, ms=300)                    # GLIDE BASS: glide
c.press("q", ms=400)
c.release("q", ms=10)
t0 = c.cpu.processorCycles
c.press("t", ms=500)
b = bends(c, t0)
tri = [v for ch, v in b if ch == 2]
check("NES glide: the next note starts bent down to the last one, slides up to centre",
      tri and tri[0] < -800 and abs(tri[-1]) <= 16 and tri == sorted(tri), tri[:8])
c.release("t", ms=200)
c.midi_in(0xC0, 0, ms=300)

# ---------------------------------------------------------------- GLITCH
c.tap("f7", ms=100)
check("F7: GLITCH, no text", c.v("vizOn") == 2 and "VISUALIZER" not in "".join(c.screen_row(r) for r in range(25)))
c.tap("f5", ms=100)
for chord in (("q", "e", "t"), ("w", "r", "y")):
    c.press(*chord, ms=700)
    c.release(*chord, ms=20)
full = sum(1 for i in range(1000) if c.raw[0x400 + i] != 32)
check("playing fills the screen with glitch", full > 150, full)
c.tap("f5", ms=10)
c.run_ms(2500)
left = sum(1 for i in range(1000) if c.raw[0x400 + i] != 32)
check("stopped: it dissolves", left < 30, left)
c.set("vizKick", 1)
c.run_ms(20)
check("a kick shakes the picture", c.v("gShake") > 0)
c.tap("return", ms=100)
check("menu from GLITCH: the picture still", c.v("menuOn") == 1 and c.raw[0xD016] & 7 == 0 and c.raw[0xD011] & 7 == 3)
c.press("lshift", ms=10); c.tap("return", ms=100); c.release("lshift", ms=100)
check("closing the menu: back to GLITCH", c.v("vizOn") == 2 and c.v("menuOn") == 0)
c.tap("f7", ms=200)
check("F7: the play screen, still and black", c.v("vizOn") == 0 and c.screen_row(4).startswith("SID") and c.raw[0xD021] == 0
      and c.raw[0xD011] & 7 == 3)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
