#!/usr/bin/env python3
"""Fat Chip 64 v0.11: MIDI in (Kerberos MIDI IN), e.g. the Yamaha SHS-10:
incoming notes play like overlay keys, H / J octave, channel filter."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def notes_on(msgs):
    on = {}
    for _, s, a, b in msgs:
        ch = s & 15
        if (s & 0xF0) == 0x90 and b:
            on[ch] = a
        elif (s & 0xF0) == 0x80 or ((s & 0xF0) == 0x90 and not b):
            if on.get(ch) == a:
                del on[ch]
    return on


def sounding(c):
    return set(notes_on(c.midi()).values())


c = C64()
c.run_ms(200)
check("screen: MIDI IN line, octave +0, nothing received yet",
      c.screen_row(16).startswith("MIDI IN  OCT +0") and "CH" not in c.screen_row(16), c.screen_row(16))

# ---------------------------------------------------------------- one note
c.midi_in(0x90, 60, 64, ms=140)             # SHS-10: fixed velocity 64, channel 1
on = notes_on(c.midi())
check("note-on ch 1: plays like an overlay key (GB pulses, NES, Fat Bass folded to C2)",
      on.get(0) == 60 and on.get(1) == 60 and on.get(5) == 60 and on.get(2) == 36 and on.get(7) == 36, on)
check("note-on: SID gated", all(c.raw[0xD404 + 7 * v] & 1 for v in range(3)))
check("screen: last note CH 1 C 4", "LAST CH1 C 4" in c.screen_row(16).replace("  ", " "), c.screen_row(16))
check("held row shows it", "C 4" in c.screen_row(15), c.screen_row(15))
c.midi_in(0x80, 60, 64, ms=80)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("note-off: everything off", notes_on(c.midi()) == {}, notes_on(c.midi()))

# running status, velocity 0 = off, realtime and sysex in between
c.midi_in(0x90, 62, 64, 0xF8, 64, 64, ms=60)  # D4 then E4, a clock byte in the middle
check("running status + clock byte: both notes", {62, 64} <= sounding(c), sounding(c))
c.midi_in(0xFE, 62, 0, 0xF0, 0x43, 0x10, 0xF7, ms=60)
check("velocity 0 = off; sysex skipped", 62 not in sounding(c) and 64 in sounding(c), sounding(c))
c.midi_in(0x90, 64, 0, ms=60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("off again (status after sysex)", sounding(c) == set(), sounding(c))
c.midi_in(0xF0, 0x7E, 0xF7, 0x64, 64, ms=60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("data without a status (after sysex) is ignored", sounding(c) == set())

# ---------------------------------------------------------------- channels
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
n0 = len(c.midi())
c.midi_in(0x9B, 60, 64, 0x9F, 36, 127, 0x9E, 48, 64, ms=80)   # ch 12, 16, 15
check("channels 12-16 (SHS-10 accompaniment, drums) are ignored, nothing passed on",
      len(c.midi()) == n0, c.midi()[n0:])
c.midi_in(0x8B, 60, 0, 0x8F, 36, 0, 0x8E, 48, 0, ms=20)
c.midi_in(0x9A, 67, 64, ms=120)             # ch 11 plays (and the screen catches up)
check("channel 11 plays", 67 in sounding(c) and "CH11" in c.screen_row(16), c.screen_row(16))
c.midi_in(0x8A, 67, 0, ms=60)

# ---------------------------------------------------------------- octave
c.tap("j", ms=80)
check("J: +1 OCT", c.v("midiOct") == 1 and "OCT +1" in c.screen_row(16), c.screen_row(16))
c.midi_in(0x90, 60, 64, ms=60)
check("+1: note 60 plays 72", 72 in sounding(c) and notes_on(c.midi()).get(0) == 72, sounding(c))
c.tap("h", ms=40); c.tap("h", ms=80)        # -1 while the note is held
c.midi_in(0x80, 60, 0, ms=60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("octave changed mid-note: its note-off still ends it", sounding(c) == set(), sounding(c))
check("H H: -1 OCT", c.v("midiOct") == 255 and "OCT -1" in c.screen_row(16), c.screen_row(16))
for _ in range(5):
    c.tap("h", ms=30)
c.run_ms(60)
check("H stops at -4", c.v("midiOct") == 256 - 4 and "OCT -4" in c.screen_row(16), c.screen_row(16))
c.midi_in(0x90, 41, 64, ms=60)              # 41 - 48: below 0
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("-4: a note that would go below 0 is ignored", sounding(c) == set())
c.midi_in(0x80, 41, 0, 0x90, 96, 64, ms=60)
check("-4: note 96 plays 48", 48 in sounding(c), sounding(c))
c.midi_in(0x80, 96, 0, ms=40)
for _ in range(9):
    c.tap("j", ms=30)
c.run_ms(60)
check("J stops at +4", c.v("midiOct") == 4)
c.midi_in(0x90, 96, 64, ms=60)              # 96 + 48 = 144: over 127
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("+4: a note over 127 is ignored", sounding(c) == set())
c.midi_in(0x80, 96, 0, ms=20)
for _ in range(4):
    c.tap("h", ms=30)
check("back to +0", c.v("midiOct") == 0)

# ---------------------------------------------------------------- with the overlay
c.press("q", ms=60)                         # overlay C3 = 48
c.midi_in(0x90, 48, 64, ms=60)              # the same note from MIDI
check("overlay key + the same MIDI note: one note (counted once)", c.v("heldCount") == 1, c.v("heldList", 8))
c.midi_in(0x80, 48, 0, ms=60)
check("MIDI note let go, the overlay key still holds it", 48 in sounding(c))
c.midi_in(0x90, 55, 64, ms=60)
check("overlay C + MIDI G: both", {48, 55} <= sounding(c) and c.v("heldList", 2) == [48, 55], c.v("heldList", 2))
c.release("q", ms=40)
c.midi_in(0x80, 55, 0, ms=60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("all let go: silent", sounding(c) == set())

# ---------------------------------------------------------------- SMART latch, modes, K, arp
c.tap("=", ms=60)                           # SMART
c.midi_in(0x90, 60, 64, 0x90, 64, 64, 0x90, 67, 64, ms=60)
c.midi_in(0x80, 60, 0, 0x80, 64, 0, 0x80, 67, 0, ms=100)
check("SMART latch: a MIDI chord keeps sounding after release", {60, 64, 67} <= sounding(c), sounding(c))
c.run_ms(700)
c.midi_in(0x90, 62, 64, ms=40); c.midi_in(0x80, 62, 0, ms=60)
check("SMART latch: after a pause the next MIDI note starts a new chord", 62 in sounding(c) and 60 not in sounding(c), sounding(c))
c.tap("=", ms=20); c.tap("=", ms=60)       # NEXT, then OFF
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("latch off", c.v("latch") == 0 and sounding(c) == set())
c.tap("z", ms=60)                           # SMART CHORD
c.midi_in(0x90, 57, 64, ms=80)              # A3 in C major: A minor
check("SMART CHORD: a MIDI note plays its chord", c.v("heldList", 3) == [57, 60, 64], c.v("heldList", 3))
c.midi_in(0x80, 57, 0, ms=40)
c.tap("z", ms=30); c.tap("z", ms=60)        # back to POLY
c.press("k", ms=20)
c.midi_in(0x90, 62, 64, ms=40)              # K + D: key of D
c.midi_in(0x80, 62, 0, ms=20)
c.release("k", ms=60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("K + a MIDI note sets the key", c.v("keyRoot") == 2 and sounding(c) == set(), c.v("keyRoot"))
c.press("k", ms=20); c.tap("q", ms=30); c.release("k", ms=40)   # back to C
c.tap("a", ms=40)                           # UNISON arp (FREE 30 ms)
c.midi_in(0x90, 60, 64, 0x90, 64, 64, ms=10)
c.run_ms(400)
arp = [a for _, s, a, b in c.midi() if s == 0x90 and b][-8:]
check("arp: steps through the MIDI notes", set(arp) == {60, 64}, arp)
c.midi_in(0x80, 60, 0, 0x80, 64, 0, ms=200)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("arp: released, stops", sounding(c) == set(), sounding(c))
c.tap("a", ms=30); c.tap("a", ms=60)        # arp off

# ---------------------------------------------------------------- many notes, lost note-offs
c.midi_in(*[b for n in range(60, 70) for b in (0x90, n, 64)], ms=100)
check("ten MIDI notes at once: no crash, eight slots used", sum(c.v("physKey", 32)[24:]) == 8, c.v("physKey", 32)[24:])
c.midi_in(*[b for n in range(60, 70) for b in (0x80, n, 0)], ms=100)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("...all let go: silent", sounding(c) == set() and sum(c.v("physKey", 32)) == 0, sounding(c))
c.midi_in(0x90, 50, 64, ms=60)              # its note-off never comes
c.press("lshift", ms=10); c.tap("f7", ms=40); c.release("lshift", ms=10)
c.run_ms(60)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("panic: a MIDI note whose note-off was lost is let go", sounding(c) == set() and sum(c.v("physKey", 32)) == 0)
c.midi_in(0x90, 52, 64, ms=60)
check("after panic MIDI in plays again", 52 in sounding(c), sounding(c))
c.midi_in(0x80, 52, 0, ms=60)

# a long burst (keytar clock + notes, back to back): nothing lost
c.midi_in(*([0xF8] * 40 + [0x90, 72, 64] + [0xF8] * 40 + [0x80, 72, 0]), ms=100)
check("a back-to-back burst: no receive overruns", c.rx_overrun == 0, c.rx_overrun)
c.run_ms(900)                               # (v0.19: the NES rings out with the SID)
check("...and its notes came through", sounding(c) == set() and c.v("lastInNote") == 72)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
