#!/usr/bin/env python3
"""Fat Chip 64 v0.21: voice priority. Polyphony > Fat Bass > REPEAT's echo
voices > stacking: every held note gets a voice before Fat Bass, and Fat Bass
before the echoes."""
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


NOTES = [48, 52, 55, 59, 62, 65, 69, 72]


def chord(c, n, ms=300):
    for k in NOTES[:n]:
        c.midi_in(0x90, k, 100, ms=5)
    c.run_ms(ms)


def unchord(c, n, ms=1500):
    for k in NOTES[:n]:
        c.midi_in(0x80, k, 0, ms=5)
    c.run_ms(ms)


def state(c):
    held = set(c.v("heldList", 8)[:c.v("heldCount")])
    out = c.v("vWant", 9)
    played = {n for n in out if n != NO_NOTE}
    return held, out, c.v("vFat", 9), c.v("vEcho", 9)


c = C64(channels=None)
c.run_ms(400)
check("header V0.25", "V0.25" in c.screen_row(0), c.screen_row(0))
c.set("detLock", 2)
c.set("latch", 0)                            # (no latch: each chord on its own)

# FAT, every chip on
c.press("q", ms=200)
held, out, fat, _ = state(c)
check("one note: Fat Bass on both bass voices, all nine voices play", fat[7] == fat[8] == 1 and NO_NOTE not in out, (out, fat))
c.release("q", ms=900)
chord(c, 8)
held, out, fat, _ = state(c)
check("eight notes on nine voices: every note plays and Fat Bass keeps both", held <= set(out) and fat[7] == fat[8] == 1,
      (sorted(held), out, fat))
unchord(c, 8)

# the SID off: six voices
c.set("devOn", 0)
c.set("latch", 0)
chord(c, 6)
held, out, fat, _ = state(c)
check("SID off, six notes: every note still plays (polyphony first)", len(held) == 6 and held <= set(out), (sorted(held), out))
check("... Fat Bass keeps one bass voice (before v0.21 both bass voices took it and a note went silent)", sum(fat) == 1, fat)
unchord(c, 6)
chord(c, 5)
held, out, fat, _ = state(c)
check("SID off, five notes: both bass voices are Fat Bass", held <= set(out) and sum(fat) == 2, (out, fat))
unchord(c, 5)

# ECHO PLUCK with Fat Bass: the echoes get what's spare after notes and bass
c.midi_in(0xC0, 20, ms=300)   # (voice 20: ECHO PLUCK, FX 1)
c.set("sndFat", 1)
c.set("fatBass", 1)
c.set("latch", 0)
for n, want in ((3, 2), (4, 1), (5, 0)):
    chord(c, n)
    held, out, fat, echo = state(c)
    notes_ok = held <= {o for i, o in enumerate(out) if not echo[i]}
    check(f"REPEAT, SID off, {n} notes: every note, Fat Bass x2, {want} echo voice(s)", notes_ok and sum(fat) == 2 and sum(echo) == want,
          (sorted(held), out, fat, echo))
    unchord(c, n)
c.set("devOn", 1)

# no hung notes: a bass voice that changes role still gets the right note-off
c.midi_in(0xC0, 0, ms=300)
chord(c, 1, ms=200)
for k in NOTES[1:]:
    c.midi_in(0x90, k, 100, ms=60)
unchord(c, 8)
on = {}
for _, s, a, b in c.midi():
    if s & 0xF0 == 0x90 and b:
        on[(s & 15, a)] = 1
    elif s & 0xF0 == 0x80 or (s & 0xF0 == 0x90 and not b):
        on.pop((s & 15, a), None)
check("bass voices that changed between Fat Bass and chord notes: nothing left on", not on, on)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
