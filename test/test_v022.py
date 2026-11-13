#!/usr/bin/env python3
"""Fat Chip 64 v0.22: the new keys. Banks (A S D F G) and slots (Z X C V B),
L latch, K + note / shape for key and scale, = tap, , . tempo, / mute,
SHIFT+/ dice, C= layer, RUN/STOP for beats, F5 arp."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0
NO_NOTE = 255


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def mod(c, m, key, ms=60):
    c.press(m, ms=10)
    c.tap(key, ms=ms)
    c.release(m, ms=40)


c = C64(channels=None)
c.run_ms(400)
row = lambda r: c.screen_row(r)
check("header V0.31", "V0.31" in row(0), row(0))
check("sound line: bank, slot, patch (FAT   1 FAT)", row(2).startswith("FAT   1 FAT "), row(2))

# ---- banks and slots
c.tap("s", ms=150)
check("S: PADS, the same slot (1): PADS", row(2).startswith("PADS  1 PADS ") and c.v("soundMode") == 1, row(2))
c.tap("c", ms=150)
check("C: slot 3, BREATHING PAD", row(2).startswith("PADS  3 BREATHING PAD"), row(2))
c.tap("d", ms=150)
check("D: LEADS slot 3, SCREAMER", row(2).startswith("LEADS 3 SCREAMER"), row(2))
c.tap("f", ms=150)
check("F: BASS has no slot 3: its first patch, GLIDE BASS", row(2).startswith("BASS  1 GLIDE BASS"), row(2))
n0 = c.v("soundMode")
c.tap("v", ms=150)
check("V: an empty slot in BASS does nothing", c.v("soundMode") == n0, row(2))
c.tap("x", ms=150)
check("X: WAVE BASS", row(2).startswith("BASS  2 WAVE BASS"), row(2))
c.midi_in(0xC0, 22, ms=200)   # (v0.24: voice 22 = FX 3)
check("a program change (VIBRAPHONE) shows its bank and slot: FX 3", row(2).startswith("FX    3 VIBRAPHONE"), row(2))
c.tap("a", ms=150)
check("A: FAT, slot 3 (COMBO ORGAN)", row(2).startswith("FAT   3 COMBO ORGAN"), row(2))
c.tap("z", ms=150)

# ---- latch
c.tap("l", ms=60)
check("L: latch on (SMART)", c.v("latch") == 1, c.v("latch"))
mod(c, "cbm", "l")
check("C= + L: latch style HOLD, the latch follows", c.v("latchStyle") == 1 and c.v("latch") == 2, (c.v("latchStyle"), c.v("latch")))
c.tap("l", ms=60)
check("L again: latch off", c.v("latch") == 0)
mod(c, "cbm", "l"); mod(c, "cbm", "l")
check("C= + L twice more: back to SMART", c.v("latchStyle") == 0)

# ---- arp on F5, type on C= + A
c.tap("f5", ms=60)
check("F5: arp on, UNISON", c.v("arpMode") == 1, c.v("arpMode"))
mod(c, "cbm", "a")
check("C= + A while it runs: SPARKLE at once", c.v("arpMode") == 2 and c.v("arpLast") == 2, (c.v("arpMode"), c.v("arpLast")))
c.tap("f5", ms=60)
check("F5: off", c.v("arpMode") == 0)
c.tap("f5", ms=60)
check("F5: on again, in the type chosen (SPARKLE)", c.v("arpMode") == 2)
c.tap("f5", ms=60)
mod(c, "cbm", "a")
check("C= + A while off: UNISON chosen, still off", c.v("arpMode") == 0 and c.v("arpLast") == 1)

# ---- tempo
b0 = c.v("bpm")
c.tap(".", ms=60)
check(". : +1 BPM", c.v("bpm") == b0 + 1, (b0, c.v("bpm")))
c.tap(",", ms=60)
c.tap(",", ms=60)
check(", , : -2", c.v("bpm") == b0 - 1)
mod(c, "lshift", ".")
check("SHIFT + . : +10", c.v("bpm") == b0 + 9, c.v("bpm"))
for _ in range(5):
    c.tap("=", ms=250)
check("= tapped every 0.5 s: 120 BPM", abs(c.v("bpm") - 120) <= 2, c.v("bpm"))

# ---- mute, dice, undo
c.tap("/", ms=80)
check("/ : mute", c.v("sidMute") == 1)
c.tap("/", ms=80)
check("/ again: unmuted", c.v("sidMute") == 0)
size = c.sym["PATCH_SIZE"]
before = c.v("livePatch", size)
changed = 0
for _ in range(4):
    mod(c, "lshift", "/", ms=120)
    if c.v("livePatch", size)[:-17] != before[:-17]:
        changed += 1
check("SHIFT + / : the dice change the patch (most rolls)", changed >= 3, changed)
check("... and mark the name with *", row(2)[8:24].rstrip().endswith("*"), row(2))
rolled = c.v("livePatch", size)
mod(c, "lshift", "/", ms=120)
mod(c, "cbm", "/", ms=120)
check("C= + / : back to the patch before the last roll", c.v("livePatch", size) == rolled)
c.tap("z", ms=150)
check("Z: the built-in FAT again", c.v("livePatch", size) == before)

# ---- K: key and scale
def keyshape(*keys):
    c.tap("k", ms=40)
    t0 = c.cpu.processorCycles
    c.press(*keys, ms=80)
    played = [1 for _, s, a, b in c.midi(since=t0) if s & 0xF0 == 0x90 and b]
    c.release(*keys, ms=80)
    return played

p = keyshape("e")
check("K, E: key E major; the E didn't play", c.v("keyRoot") == 4 and c.v("keyScale") == 0 and not p, (c.v("keyRoot"), c.v("keyScale"), p))
check("key line shows E MAJOR", row(9).startswith("KEY E  MAJOR"), row(9))
keyshape("w", "r")
check("K, D + F (a minor third): D minor", c.v("keyRoot") == 2 and c.v("keyScale") == 1, (c.v("keyRoot"), c.v("keyScale")))
keyshape("q", "3", "5")
check("K, C Eb F#: C diminished", c.v("keyRoot") == 0 and c.v("keyScale") == 9 and "DIMINISHED" in row(9), row(9))
keyshape("q", "e", "6")
check("K, C E G#: C whole tone", c.v("keyScale") == 8 and "WHOLE TONE" in row(9), row(9))
keyshape("t", "u", "o", "@")
check("K, G B D F: G mixolydian (lowest G; F = flat 7th)", c.v("keyRoot") == 7 and c.v("keyScale") == 5, (c.v("keyRoot"), c.v("keyScale")))
c.tap("k", ms=40)
check("K: the key line asks (?)", row(9).startswith("KEY ? "), row(9))
c.tap("k", ms=40)
check("K again: never mind", c.v("kArm") == 0)
keyshape("q", "e", "6")
c.tap("z", ms=40)                            # (POLY -> SMART CHORD now on C= + Z)
mod(c, "cbm", "z")
c.press("q", ms=200)
held = c.v("heldList", 8)[:c.v("heldCount")]
check("SMART CHORD in C whole tone: C E G# (augmented)", held[:3] == [48, 52, 56], held)
c.release("q", ms=300)
mod(c, "cbm", "z"); mod(c, "cbm", "z")
keyshape("q")

# ---- RUN/STOP
c.tap("runstop", ms=100)
check("RUN/STOP tapped: the beat starts", c.v("beatRun") == 1)
c.press("runstop", ms=10)
c.tap("s", ms=60)
c.release("runstop", ms=60)
check("RUN/STOP + S: beat 2 (JUNGLE), still running", c.v("beatSel") == 1 and c.v("beatRun") == 1, (c.v("beatSel"), c.v("beatRun")))
check("... and S didn't change the bank", row(2).startswith("FAT   1"), row(2))
c.tap("runstop", ms=100)
check("RUN/STOP tapped: stops", c.v("beatRun") == 0)

# ---- C= layer odds and ends
mod(c, "cbm", "f1")
check("C= + F1: SID off", c.v("devOn") == 0)
mod(c, "cbm", "f1")
mod(c, "cbm", ":")
check("C= + : : MIDI in octave up", c.v("midiOct") == 1)
mod(c, "cbm", ";")
check("C= + ; : back down", c.v("midiOct") == 0)
s0 = c.v("spaceAct")
mod(c, "cbm", ".")
check("C= + . : SPACE's next action", c.v("spaceAct") == s0 + 1, (s0, c.v("spaceAct")))
mod(c, "cbm", ",")
mod(c, "cbm", "c")
check("C= + C: MONO", c.v("monoMode") == 1)
mod(c, "cbm", "c")

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
