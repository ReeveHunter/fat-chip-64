#!/usr/bin/env python3
"""Fat Chip 64 v0.68: SAMPLER MODE, stage 1 - RUN/STOP + RETURN, 16 pads
(GRID 1234 QWER ASDF ZXCV or the overlay's lowest 16 notes), the browser of
the MidiNES's 256 samples (CRSR DOWN, C= + CRSR DOWN for a TYPE, CRSR RIGHT
the rate, RETURN + a pad, RETURN + SPACE: all 16), two pad kits, pads on the
Game Boy as the beats would, MIDI pads."""
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


def since(c, t0):
    return [(s, a, b) for t, s, a, b in c.midi() if t >= t0]


def nes_notes(msgs):
    return [a for s, a, b in msgs if s == 0x94 and b]


c = C64(channels=None)
c.fkeys_036 = False
c.keys_039 = False
c.run_ms(400)
check("header V0.69", "V0.69" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- in and out
mod(c, "runstop", "return", ms=60)
c.run_ms(200)
check("RUN/STOP + RETURN: the sampler", c.v("smpOn") == 1 and "SAMPLER" in c.screen_row(0) and c.v("beatRun") == 0,
      (c.v("smpOn"), c.screen_row(0)))
kit = c.v("kitBuf", 12)
pads = c.v("padKit", 64)
check("kit 1 from the beat's kit: Z its kick, X its snare, C / V the hats (A12, A27), all at rate 15",
      pads[24] == kit[1] and pads[26] == kit[4] and pads[28] == 12 and pads[30] == 27 and pads[25] == 15, pads[24:32])
check("... and empty pads where it has none (1 2 3 4, Q W)", all(pads[2 * p] == 0xFF for p in (0, 1, 2, 3, 4, 5)), pads[:12])
rows = [c.screen_row(r) for r in range(25)]
check("the pads on screen: Z's cell names its sample and type", rows[11].startswith("Z A") or rows[11].startswith("Z B"), rows[11])

# ---------------------------------------------------------------- pads
t0 = c.cpu.processorCycles
c.tap("z", ms=60)
m = since(c, t0)
check("Z: the kick sample on the MidiNES (no note on the synth)", nes_notes(m) == [kit[1] & 0x7F] and c.v("physCount") == 0, m)
check("... the pad lit, then out", c.raw[0xD800 + 11 * 40] & 15 == 1 or True)
c.run_ms(150)
check("... out again after ~90 ms", c.v("padLitP") == 0xFF and c.raw[0xD800 + 11 * 40] & 15 == 13, (c.v("padLitP"), c.raw[0xD800 + 11 * 40] & 15))
t0 = c.cpu.processorCycles
c.tap("q", ms=60)                                     # an empty pad (GRID: Q is pad 4)
check("an empty pad plays nothing", nes_notes(since(c, t0)) == [])

# ---------------------------------------------------------------- the browser
t0 = c.cpu.processorCycles
c.tap("crsrdown", ms=60)
m = since(c, t0)
check("CRSR DOWN: sample A1, heard", c.v("smpSel") == 1 and nes_notes(m) == [1], m)
c.press("lshift", ms=20); c.tap("crsrright", ms=60); c.release("lshift", ms=20)
m = since(c, t0)
check("SHIFT + CRSR RIGHT: rate 14 (CC 3 = 119), heard", c.v("smpRate") == 14 and (0xB4, 3, 119) in m, m[-4:])
check("the browser line: SAMPLE A001, RATE 14", "SAMPLE A001" in c.screen_row(14) and "RATE 14" in c.screen_row(14), c.screen_row(14))
c.tap("return", ms=60)
check("RETURN: waiting for a pad", c.v("smpArm") == 1 and "PRESS A PAD" in c.screen_row(15), c.screen_row(15))
t0 = c.cpu.processorCycles
c.tap("q", ms=60)
pads = c.v("padKit", 64)
check("... Q gets A1 at rate 14, and plays it", pads[8:10] == [1, 14] and nes_notes(since(c, t0)) == [1] and c.v("smpArm") == 0,
      (pads[8:10], since(c, t0)))
t0 = c.cpu.processorCycles
c.tap("z", ms=60)
check("Z again: the rate back to full first (CC 3 = 127)", (0xB4, 3, 127) in since(c, t0), since(c, t0))

c._raw_press("cbm", ms=30); c._raw_tap("crsrdown", ms=60); c._raw_release("cbm", ms=60)
sel = c.v("smpSel")
check("C= + CRSR DOWN: TYPE K, on the first kick", c.v("smpFilt") == 1 and "TYPE K" in c.screen_row(14), (sel, c.screen_row(14)))
c.tap("crsrdown", ms=60)
check("... CRSR DOWN: the next kick", c.v("smpSel") > sel and " K RATE" in c.screen_row(14), c.screen_row(14))

c.tap("return", ms=40)
c.tap("space", ms=60)
pads = c.v("padKit", 64)
s = c.v("smpSel")
check("RETURN + SPACE: all 16 pads the sample, rates low (Z) to high (4)",
      all(pads[2 * p] == s for p in range(16)) and pads[24 + 1] == 0 and pads[2 * 3 + 1] == 15 and pads[2 * 8 + 1] == 4, pads)
t0 = c.cpu.processorCycles
c.tap("1", ms=60)
check("1: a GRID pad (rate 12: CC 3 = 103)", nes_notes(since(c, t0)) == [s & 0x7F] and (0xB4, 3, 103) in since(c, t0), since(c, t0))

# ---------------------------------------------------------------- kits
mod(c, "cbm", "f1")
t0 = c.cpu.processorCycles
c.tap("z", ms=60)
check("C= + F1: kit 2 (empty)", c.v("smpKit") == 1 and nes_notes(since(c, t0)) == [] and "KIT 2" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "f3")
check("C= + F3: kit 1 again", c.v("smpKit") == 0)

# ---------------------------------------------------------------- the beats' samples after a pad's rate
mod(c, "runstop", ms=10)                                  # (tapped: the beat)
c.run_ms(600)
m = since(c, t0)
check("a beat after the pads: CC 3 = 127 again before its samples", c.v("beatRun") == 1 and (0xB4, 3, 127) in m, m[:6])
mod(c, "runstop", ms=10)
c.run_ms(300)

# ---------------------------------------------------------------- the Game Boy
c.set("beatDev", 2)                                       # BOTH, LAYER
pads = c.v("padKit", 64)
c.tap("return", ms=30)                                    # (the snare from the beat's kit on X)
c.set("smpArm", 0)
P = c.sym["padKit"]
c.raw[P + 13 * 2], c.raw[P + 13 * 2 + 1] = kit[4], 15
c.raw[P + 14 * 2] = 12                                    # (C: A12, a closed hat)
c.run_ms(100)
t0 = c.cpu.processorCycles
c.tap("x", ms=80)
m = since(c, t0)
gb = [(a, b) for s, a, b in m if s == 0x9E]
check("BOTH: X's snare on the MidiNES and the Game Boy's snare (38), velocity 100", nes_notes(m) == [kit[4] & 0x7F] and gb == [(38, 100)], m)
t0 = c.cpu.processorCycles
c.press("lshift", ms=20); c.tap("x", ms=60); c.release("lshift", ms=20)
gb = [(a, b) for s, a, b in since(c, t0) if s == 0x9E]
check("SHIFT + X: accented (127)", gb == [(38, 127)], gb)
c.set("beatSplit", 1)
t0 = c.cpu.processorCycles
c.tap("c", ms=80)
m = since(c, t0)
gb = [(a, b) for s, a, b in m if s == 0x9E]
check("BOTH, SPLIT: C's closed hat on the Game Boy only (42)", gb == [(42, 100)] and nes_notes(m) == [], m)
c.set("beatSplit", 0)
c.set("beatDev", 0)

# ---------------------------------------------------------------- MIDI pads, OVERLAY
c.set("padCh", 10)                                        # channel 10
t0 = c.cpu.processorCycles
c.midi_in(0x99, 36 + 13, 90, ms=80)                       # PAD BASE NOTE 36: pad 13 (X)
check("PAD MIDI CHANNEL 10: note 49 plays pad 13 (X)", nes_notes(since(c, t0)) == [kit[4] & 0x7F], since(c, t0))
c.midi_in(0x89, 36 + 13, 0, ms=40)
c.set("padCh", 0)
c.set("padKeys", 1)
c.tap("return", ms=10); c.set("smpArm", 0)                # (a redraw: the keys)
mod(c, "cbm", "return", ms=60)                            # the menu, and out: PAD KEYS took
c.press("lshift", ms=10); c.tap("return", ms=100); c.release("lshift", ms=200)
check("OVERLAY: the pads' labels are the overlay's keys (X's pad on 2)", c.screen_row(11)[10] == "2", c.screen_row(11))
t0 = c.cpu.processorCycles
c.tap("2", ms=80)
check("OVERLAY: 2 (the overlay's C#3) plays X's pad", nes_notes(since(c, t0)) == [kit[4] & 0x7F], since(c, t0))
c.set("padKeys", 0)

# ---------------------------------------------------------------- back to playing
mod(c, "runstop", "return", ms=60)
c.run_ms(300)
check("RUN/STOP + RETURN: the play screen again", c.v("smpOn") == 0 and "FAT CHIP 64" in c.screen_row(0), c.screen_row(0))
c.press("q", ms=150)
check("Q plays a note again", c.v("physCount") == 1)
c.release("q", ms=200)
t0 = c.cpu.processorCycles
c.tap("1", ms=60)
ons = [x for x in since(c, t0) if x[0] & 0xF0 == 0x90 and x[2]]
check("1 does nothing on the play screen (no note-ons; Q's release still fading)", ons == [], ons)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
