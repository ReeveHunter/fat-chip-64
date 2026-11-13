#!/usr/bin/env python3
"""Fat Chip 64 v0.06: notes modes (POLY, SMART CHORD, EXTENSIONS), the key,
the PADS sound, and the SPARKLE arp octave."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


c = C64()
c.run_ms(150)


def held():
    return c.v("heldList", c.v("heldCount")) if c.v("heldCount") > 1 else (
        [c.v("heldList")] if c.v("heldCount") else [])


def chord(*keys, ms=80):
    c.press(*keys, ms=ms)
    h = held()
    c.release(*keys, ms=60)
    return h


check("key line: key C MAJOR, POLY; sound line: FAT", c.screen_row(9).startswith("KEY C  MAJOR      POLY")
      and c.screen_row(2).startswith("FAT   1 FAT "), (c.screen_row(9), c.screen_row(2)))
check("POLY: one key, one note", chord("w") == [50])

c.tap("z", ms=60)
check("Z: SMART CHORD", c.v("playMode") == 1 and "SMART CHRD" in c.screen_row(9), c.screen_row(9))
check("C -> C major (C E G)", chord("q") == [48, 52, 55])
check("D -> D minor (D F A)", chord("w") == [50, 53, 57])
check("E -> E minor", chord("e") == [52, 55, 59])
check("G -> G major", chord("t") == [55, 59, 62])
check("B -> B diminished", chord("u") == [59, 62, 65])
check("C# (outside the key) -> C# major", chord("2") == [49, 53, 56])
check("two keys merge: C + G", chord("q", "t") == [48, 52, 55, 59, 62])
c.press("q", ms=80)
on = {}
for _, s, a, b in c.midi():
    ch = s & 15
    if (s & 0xF0) == 0x90 and b:
        on[ch] = a
    elif (s & 0xF0) == 0x80 and on.get(ch) == a:
        del on[ch]
check("smart chord voices: bass on the root, chord tones spread", on.get(2) == 36 and on.get(7) == 36
      and {48, 52, 55} <= set(on.values()), on)
c.release("q", ms=60)

# key: hold K, press a note
c.press("k", ms=20); c.tap("t", ms=30); c.release("k", ms=60)
check("K + G: key of G", c.v("keyRoot") == 7 and c.screen_row(9).startswith("KEY G "), c.screen_row(9))
check("in G: F# -> F# diminished", chord("5") == [54, 57, 60])
check("in G: F (outside) -> F major", chord("r") == [53, 57, 60])
check("K + note doesn't play the note", c.v("heldCount") == 0)
c.tap("l", ms=60)
check("L: G MINOR", c.v("keyScale") == 1 and "MINOR" in c.screen_row(9), c.screen_row(9))
check("in G minor: G -> G minor", chord("t") == [55, 58, 62])
check("in G minor: D -> D minor (natural minor)", chord("w") == [50, 53, 57])
c.tap("l", ms=30)
c.press("k", ms=20); c.tap("q", ms=30); c.release("k", ms=60)

c.tap("z", ms=60)
check("Z: EXT 7TH", c.v("playMode") == 2 and "EXT 7TH" in c.screen_row(9), c.screen_row(9))
check("C -> Cmaj7", chord("q") == [48, 52, 55, 59])
check("D -> Dm7", chord("w") == [50, 53, 57, 60])
check("G -> G7", chord("t") == [55, 59, 62, 65])
c.tap("x", ms=60)
check("X: EXT 9TH", "EXT 9TH" in c.screen_row(9) and chord("q") == [48, 52, 55, 59, 62])
c.tap("x", ms=20); c.tap("x", ms=60)
check("X X: EXT 13TH: C -> C E G B D F A", "EXT 13TH" in c.screen_row(9)
      and chord("q") == [48, 52, 55, 59, 62, 65, 69], c.screen_row(9))
check("outside the key with 13ths: C# 7 9 11 13", chord("2") == [49, 53, 56, 59, 63, 66, 70])
check("two 13th chords: at most 8 notes, lowest kept", chord("q", "w") == [48, 50, 52, 53, 55, 57, 59, 60])
c.tap("x", ms=30)                           # back to 7th

# arp over a smart chord: one key arpeggiates the chord
c.tap("z", ms=20)                           # EXT -> DRONE (v0.27)
c.tap("z", ms=20)                           # -> POLY
c.tap("z", ms=60)                           # -> SMART CHORD
check("Z cycles back round to SMART CHORD", c.v("playMode") == 1, c.v("playMode"))
c.tap("a", ms=40)                           # arp UNISON
t0 = c.cpu.processorCycles
c.press("q", ms=1000)
notes = [a for cyc, s, a, b in c.midi(since=t0) if s == 0x90 and b]
check("arp + smart chord: one key arpeggiates C E G", notes[:3] == [48, 52, 55], notes)
c.release("q", ms=60)
c.tap("a", ms=20); c.tap("a", ms=40)         # SPARKLE -> OFF
c.tap("z", ms=20); c.tap("z", ms=20); c.tap("z", ms=60)         # CHORD -> EXT -> DRONE -> POLY
check("back to POLY", c.v("playMode") == 0)

# ---------------------------------------------------------------- latched chord + a mode change
c.tap("=", ms=30)                           # latch SMART
c.press("q", "t", ms=60); c.release("q", "t", ms=60)
check("latched in POLY: C G", held() == [48, 55], held())
c.tap("z", ms=80)                           # -> SMART CHORD
check("mode change while latched: the chord stays as it was", held() == [48, 55] and c.screen_row(9)[28:38] == "LATCH NEXT",
      (held(), c.screen_row(9)))
check("...but the screen shows the new mode", "SMART CHRD" in c.screen_row(9))
c.tap("w", ms=80)                           # next press: new chord, new mode (even though quick)
check("next key: a new chord in the new mode (D minor)", held() == [50, 53, 57], held())
c.press("k", ms=20); c.tap("t", ms=30); c.release("k", ms=80)
check("key change while latched: D minor keeps sounding", held() == [50, 53, 57], held())
c.tap("w", ms=80)
check("next key: D in G major = D major", held() == [50, 54, 57], held())
c.press("k", ms=20); c.tap("q", ms=30); c.release("k", ms=40)
c.tap("=", ms=40)                           # (NEXT already, from the key change): latch off
c.press("q", ms=60)
c.tap("z", ms=80)                           # latch off: applies at once to held keys
check("latch off: a mode change applies at once", held() == [48, 52, 55, 59], held())
c.release("q", ms=40)
c.tap("z", ms=20); c.tap("z", ms=20); c.tap("z", ms=60)         # EXT -> DRONE -> POLY -> CHORD
c.tap("z", ms=60)
check("(mode back to EXT for the next part)", c.v("playMode") == 2)
c.tap("z", ms=20); c.tap("z", ms=60)

# ---------------------------------------------------------------- SPARKLE octave
c.tap("a", ms=20); c.tap("a", ms=60)         # SPARKLE
t0 = c.cpu.processorCycles
c.press("q", ms=500)
up1 = [a for cyc, s, a, b in c.midi(since=t0) if s in (0x90, 0x91) and b]
c.release("q", ms=60)
check("SPARKLE: arp an octave up by default", up1 and set(up1) == {60}, up1)
c.tap("f", ms=60)
check("F: +2 OCT", "+2 OCT" in c.screen_row(10), c.screen_row(10))
t0 = c.cpu.processorCycles
c.press("q", ms=500)
up2 = [a for cyc, s, a, b in c.midi(since=t0) if s in (0x90, 0x91) and b]
c.release("q", ms=60)
check("+2: two octaves up", set(up2) == {72}, up2)
c.tap("f", ms=150)
check("F again: +0", "+0 OCT" in c.screen_row(10))
c.tap("f", ms=40)
c.tap("a", ms=40)                           # arp off

# ---------------------------------------------------------------- PADS sound
t0 = c.cpu.processorCycles
c.tap("v", ms=150)
check("V: PADS on screen", c.screen_row(2).startswith("PADS  1 PADS "), c.screen_row(2))
check("PADS: SID slow attack, long release, pulse wave", c.raw[0xD405] == 0xA0 and c.raw[0xD406] == 0xFB
      and c.sid(0)[1] & 0xF0 == 0x40, (hex(c.raw[0xD405]), hex(c.raw[0xD406])))
check("PADS: SID low-pass filter on all voices", c.raw[0xD417] == 0x77 and c.raw[0xD418] == 0x1F, hex(c.raw[0xD418]))
cc = [(s & 15, a, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0]
check("PADS: Game Boy attack + release follow the SID's (v0.19) on pulses and wave",
      all((ch, 73, 32) in cc and (ch, 72, 112) in cc for ch in (0, 1, 2)), cc)     # attack 2, release 7 of 7
check("PADS: Game Boy glides (v0.19: every channel), deeper warble",
      all((ch, 5, 56) in cc for ch in (0, 1, 2)) and (0, 104, 49) in cc, cc)
f0 = c.raw[0xD416]
c.run_ms(1500)
check("PADS: the filter sweeps", c.raw[0xD416] != f0, (f0, c.raw[0xD416]))
def widths():
    return (c.raw[0xD402] | c.raw[0xD403] << 8, c.raw[0xD409] | c.raw[0xD40A] << 8)
ws = []
for _ in range(6):
    ws.append(widths())
    c.run_ms(100)
check("PADS: pulse widths wobble, each voice its own", len(set(ws)) >= 4 and sum(a != b for a, b in ws) >= 5, ws)
c.tap("m", ms=60)
check("muted in PADS: volume 0, filter mode kept", c.raw[0xD418] == 0x10, hex(c.raw[0xD418]))
c.tap("m", ms=60)
t0 = c.cpu.processorCycles
c.tap("v", ms=150)
check("V again: RAW on screen", c.screen_row(2).startswith("FAT   2 RAW "), c.screen_row(2))
regs = [(c.raw[0xD405 + 7 * v], c.raw[0xD406 + 7 * v], c.raw[0xD403 + 7 * v], c.sid(v)[1] & 0xF0) for v in range(3)]
check("RAW: SID pulse, instant attack, full sustain, instant release, widths 50/25/12.5%",
      regs == [(0x00, 0xF0, 8, 0x40), (0x00, 0xF0, 4, 0x40), (0x00, 0xF0, 2, 0x40)], regs)
check("RAW: SID filter off", c.raw[0xD417] == 0 and c.raw[0xD418] == 0x0F)
cc = [(s & 15, a, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0]
check("RAW: Game Boy instant attack and release on pulses and wave",
      all((ch, 73, 0) in cc and (ch, 72, 0) in cc for ch in (0, 1, 2)), cc)
check("RAW: Game Boy pulse 2 at 25%, wave as a pulse, no warble, no glide",
      (0, 70, 64) in cc and (1, 70, 32) in cc and (2, 71, 19) in cc and (2, 70, 64) in cc and (0, 104, 0) in cc and (1, 5, 0) in cc, cc)
check("RAW: MidiNES full volume, pulse 2 at 25%", (5, 7, 127) in cc and (5, 1, 64) in cc and (6, 1, 32) in cc, cc)
t0 = c.cpu.processorCycles
c.press("q", ms=200)
on = [x for x in c.midi(since=t0) if (x[1] & 0xF0) == 0x90 and x[3]]
check("RAW: a note: plain note-ons (no CC7 envelope on the NES)",
      len(on) == 6 and not [x for x in c.midi(since=t0) if x[1] == 0xB5 and x[2] == 7], on)
c.release("q", ms=60)
t0 = c.cpu.processorCycles
c.press("lshift", ms=12)
c.tap("v", ms=40)
c.tap("v", ms=80)
c.release("lshift", ms=150)
check("SHIFT+V twice: back to FAT", c.v("soundMode") == 0)
check("FAT: saw, filter off", c.sid(0)[1] & 0xF0 == 0x20 and c.raw[0xD417] == 0 and c.raw[0xD418] == 0x0F)
cc = [(s & 15, a, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0]
check("FAT: Game Boy envelopes, duty, wave triangle and warble back",
      (0, 73, 0) in cc and (0, 72, 48) in cc and (1, 70, 64) in cc and (2, 71, 37) in cc and (2, 70, 0) in cc and (0, 104, 24) in cc, cc)
check("FAT: MidiNES pulse 2 back to 50%", (6, 1, 64) in cc, cc)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
