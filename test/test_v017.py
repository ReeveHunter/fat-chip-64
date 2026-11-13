#!/usr/bin/env python3
"""Fat Chip 64 v0.17: bends up to two octaves on every chip (VINYL STOP,
BEND RANGE up to 24), Game Boy bend range 24; going down, Game Boy and NES
notes hold at the bottom of their channel instead of wrapping."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0
GB = (10, 11, 12)
NES = (0, 1, 2)
A_BENDDN, A_BENDUP, A_VINYL = 1, 2, 7


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def bend_series(c, t0):
    out = {}
    for _, s, a, b in c.midi(since=t0):
        if s & 0xF0 == 0xE0:
            out.setdefault(s & 15, []).append(((b << 7) | a) - 8192)
    return out


def p_tri(n):
    return round(1710 * 0.5 ** ((n - 36) / 12))


def nes_down(n, semis, pulse):
    """The MidiNES bend for note n, `semis` down (pulses twice the triangle)."""
    b = p_tri(n) * 2 * (2 ** (semis / 12) - 1)
    return -round(b * (2 if pulse else 1))


c = C64(channels=None)
c.run_ms(400)
c.set("detLock", 2)                          # (no detune on top: exact sums)
c.set("detNow", 0)
check("header V0.30", "V0.30" in c.screen_row(0), c.screen_row(0))
check("Game Boy bend range 24 sent at start (CC 85 = 127)",
      all((0xB0 | ch, 85, 127) in [(s, a, b) for _, s, a, b in c.midi()] for ch in GB))

# ---------------------------------------------------------------- VINYL STOP, two octaves
c.press("o", ms=200)                         # D4 (62): room for two octaves everywhere
f0 = c.sid(0)[0]
c.set("spaceAct", A_VINYL)
t0 = c.cpu.processorCycles
c.press("space", ms=1300)
b = bend_series(c, t0)
check("VINYL STOP: the SID two octaves down", abs(c.sid(0)[0] / f0 - 0.25) < 0.004, round(c.sid(0)[0] / f0, 4))
check("... the Game Boy pulses two octaves down (the bottom of range 24)", all(b[ch][-1] <= -8188 for ch in (10, 11)),
      [b[ch][-1] for ch in (10, 11)])
check("... the NES pulses two octaves down", all(abs(b[ch][-1] - nes_down(62, 24, True)) <= 8 for ch in (0, 1)),
      ([b[ch][-1] for ch in (0, 1)], nes_down(62, 24, True)))
check("... every bend only ever went down (no wrap round)", all(all(y <= x for x, y in zip(v, v[1:])) for v in b.values()),
      {k: v[-3:] for k, v in b.items()})
c.release("space", ms=800)
c.release("o", ms=200)

# ---------------------------------------------------------------- low notes hold at the bottom
c.press("q", ms=200)                         # C3 (48): the Game Boy pulses have one octave of room (C2)
t0 = c.cpu.processorCycles
c.press("space", ms=1300)
b = bend_series(c, t0)
gb = b.get(10, [0])[-1]
check("C3: the Game Boy pulses stop at C2 (12 of 24 semitones: -4096)", abs(gb + 4096) <= 4, gb)
nes = b.get(0, [0])[-1]
check("C3: the NES pulses stop at A1 (15 semitones down)", abs(nes - nes_down(48, 15, True)) <= 8, (nes, nes_down(48, 15, True)))
check("... and only ever went down", all(all(y <= x for x, y in zip(v, v[1:])) for v in b.values()))
c.release("space", ms=800)
c.release("q", ms=200)

# ---------------------------------------------------------------- BEND RANGE 24
c.set("bendRange", 23)
c.set("spaceAct", A_BENDUP)
c.press("t", ms=200)                         # G3 (55)
f0 = c.sid(0)[0]
t0 = c.cpu.processorCycles
c.press("space", ms=1500)
b = bend_series(c, t0)
check("BEND UP, range 24: the SID two octaves up", abs(c.sid(0)[0] / f0 - 4) < 0.02, round(c.sid(0)[0] / f0, 4))
check("... the Game Boy at the top of its range", all(b[ch][-1] >= 8180 for ch in (10, 11)), [b[ch][-1] for ch in (10, 11)])
check("... the NES pulses two octaves up (3/4 of 2p)", abs(b[0][-1] - round(p_tri(55) * 2 * 1.5)) <= 8, (b[0][-1], round(p_tri(55) * 3)))
c.release("space", ms=900)
c.release("t", ms=200)
c.set("bendRange", 1)

# menu: BEND RANGE goes to 24
c.tap("return", ms=80)
c.set("menuRow", 5)                          # PLAYING (HELP first)
c.tap("return", ms=80)
c.tap("crsrdown", ms=30); c.tap("crsrdown", ms=30)   # BEND RANGE
for _ in range(22):
    c.tap("crsrright", ms=20)
check("menu: BEND RANGE up to 24 SEMITONES", c.v("bendRange") == 23 and "24 SEMITONES" in c.screen_row(4), c.screen_row(4))
c.tap("crsrright", ms=40)
check("... then round to 1 SEMITONE", c.v("bendRange") == 0 and "1 SEMITONE" in c.screen_row(4), c.screen_row(4))
c.press("lshift", ms=10); c.tap("return", ms=80); c.tap("return", ms=80); c.release("lshift", ms=100)

# VINYL STOP let go from a stop: the beat comes straight back
c.set("spaceAct", A_VINYL)
c.tap("f5", ms=300)
c.press("q", ms=100)
c.press("space", ms=1500)
t0 = c.cpu.processorCycles
c.release("space", ms=300)
dr = [1 for _, s, a, b in c.midi(since=t0) if (s & 15) in (3, 4) and s & 0xF0 == 0x90 and b]
check("VINYL STOP let go: drums back within 300 ms", dr, len(dr))
c.release("q", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
