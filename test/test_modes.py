#!/usr/bin/env python3
"""Fat Chip 64 v0.06: notes modes (POLY, SMART CHORD, EXTENSIONS), the key,
the PADS sound, and the SPARKLE arp octave."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

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


check("mode line: POLY, key C MAJOR, FAT", c.screen_row(24).startswith("Z POLY") and "KEY C  MAJOR" in c.screen_row(24)
      and c.screen_row(24).rstrip().endswith("V FAT"), c.screen_row(24))
check("POLY: one key, one note", chord("w") == [50])

c.tap("z", ms=60)
check("Z: SMART CHORD", c.v("playMode") == 1 and "SMART CHRD" in c.screen_row(24), c.screen_row(24))
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
check("K + G: key of G", c.v("keyRoot") == 7 and "KEY G" in c.screen_row(24), c.screen_row(24))
check("in G: F# -> F# diminished", chord("5") == [54, 57, 60])
check("in G: F (outside) -> F major", chord("r") == [53, 57, 60])
check("K + note doesn't play the note", c.v("heldCount") == 0)
c.tap("l", ms=60)
check("L: G MINOR", c.v("keyMinor") == 1 and "MINOR" in c.screen_row(24), c.screen_row(24))
check("in G minor: G -> G minor", chord("t") == [55, 58, 62])
check("in G minor: D -> D minor (natural minor)", chord("w") == [50, 53, 57])
c.tap("l", ms=30)
c.press("k", ms=20); c.tap("q", ms=30); c.release("k", ms=60)

c.tap("z", ms=60)
check("Z: EXT 7TH", c.v("playMode") == 2 and "EXT 7TH" in c.screen_row(24), c.screen_row(24))
check("C -> Cmaj7", chord("q") == [48, 52, 55, 59])
check("D -> Dm7", chord("w") == [50, 53, 57, 60])
check("G -> G7", chord("t") == [55, 59, 62, 65])
c.tap("x", ms=60)
check("X: EXT 9TH", "EXT 9TH" in c.screen_row(24) and chord("q") == [48, 52, 55, 59, 62])
c.tap("x", ms=20); c.tap("x", ms=60)
check("X X: EXT 13TH: C -> C E G B D F A", "EXT 13TH" in c.screen_row(24)
      and chord("q") == [48, 52, 55, 59, 62, 65, 69], c.screen_row(24))
check("outside the key with 13ths: C# 7 9 11 13", chord("2") == [49, 53, 56, 59, 63, 66, 70])
check("two 13th chords: at most 8 notes, lowest kept", chord("q", "w") == [48, 50, 52, 53, 55, 57, 59, 60])
c.tap("x", ms=30)                           # back to 7th

# arp over a smart chord: one key arpeggiates the chord
c.tap("z", ms=20)                           # EXT -> POLY
c.tap("z", ms=60)                           # -> SMART CHORD
check("Z cycles back round to SMART CHORD", c.v("playMode") == 1, c.v("playMode"))
c.tap("a", ms=40)                           # arp UNISON
t0 = c.cpu.processorCycles
c.press("q", ms=1000)
notes = [a for cyc, s, a, b in c.midi(since=t0) if s == 0x90 and b]
check("arp + smart chord: one key arpeggiates C E G", notes[:3] == [48, 52, 55], notes)
c.release("q", ms=60)
c.tap("a", ms=20); c.tap("a", ms=40)         # SPARKLE -> OFF
c.tap("z", ms=20); c.tap("z", ms=60)         # CHORD -> EXT -> POLY
check("back to POLY", c.v("playMode") == 0)

# ---------------------------------------------------------------- SPARKLE octave
c.tap("a", ms=20); c.tap("a", ms=60)         # SPARKLE
t0 = c.cpu.processorCycles
c.press("q", ms=500)
up1 = [a for cyc, s, a, b in c.midi(since=t0) if s in (0x90, 0x91) and b]
c.release("q", ms=60)
check("SPARKLE: arp an octave up by default", up1 and set(up1) == {60}, up1)
c.tap("f", ms=60)
check("F: +2 OCT", "+2 OCT" in c.screen_row(19), c.screen_row(19))
t0 = c.cpu.processorCycles
c.press("q", ms=500)
up2 = [a for cyc, s, a, b in c.midi(since=t0) if s in (0x90, 0x91) and b]
c.release("q", ms=60)
check("+2: two octaves up", set(up2) == {72}, up2)
c.tap("f", ms=60)
check("F again: +0", "+0 OCT" in c.screen_row(19))
c.tap("f", ms=40)
c.tap("a", ms=40)                           # arp off

# ---------------------------------------------------------------- PADS sound
t0 = c.cpu.processorCycles
c.tap("v", ms=80)
check("V: PADS on screen", c.screen_row(24).rstrip().endswith("V PADS"), c.screen_row(24))
check("PADS: SID slow attack, long release, pulse wave", c.raw[0xD405] == 0xA0 and c.raw[0xD406] == 0xFB
      and c.sid(0)[1] & 0xF0 == 0x40, (hex(c.raw[0xD405]), hex(c.raw[0xD406])))
check("PADS: SID low-pass filter on all voices", c.raw[0xD417] == 0x77 and c.raw[0xD418] == 0x1F, hex(c.raw[0xD418]))
cc = [(s & 15, a, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0]
check("PADS: Game Boy slow attack + release on pulses and wave",
      all((ch, 73, 88) in cc and (ch, 72, 100) in cc for ch in (0, 1, 2)), cc)
check("PADS: Game Boy pulse 2 glides, deeper warble", (1, 5, 64) in cc and (0, 104, 48) in cc, cc)
f0 = c.raw[0xD416]
c.run_ms(1500)
check("PADS: the filter sweeps", c.raw[0xD416] != f0, (f0, c.raw[0xD416]))
pw = (c.raw[0xD402], c.raw[0xD409])
c.run_ms(300)
check("PADS: pulse widths wobble, each voice its own", (c.raw[0xD402], c.raw[0xD409]) != pw and pw[0] != pw[1], pw)
c.tap("m", ms=60)
check("muted in PADS: volume 0, filter mode kept", c.raw[0xD418] == 0x10, hex(c.raw[0xD418]))
c.tap("m", ms=60)
t0 = c.cpu.processorCycles
c.tap("v", ms=80)
check("V again: FAT: saw, filter off", c.sid(0)[1] & 0xF0 == 0x20 and c.raw[0xD417] == 0 and c.raw[0xD418] == 0x0F)
cc = [(s & 15, a, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0]
check("FAT: Game Boy envelopes and glide back", (0, 73, 0) in cc and (1, 5, 0) in cc and (0, 104, 24) in cc, cc)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
