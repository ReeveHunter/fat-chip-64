#!/usr/bin/env python3
"""Fat Chip 64 v0.32: SPLIT (was CHORD + LEAD): OFF / KEY / LOW NOTE / LATCH 3.
KEY splits the keyboard: on the C64 by key (it stays put when the octave
changes), over MIDI by note as sent. C= + V tapped steps SPLIT; held + a note
sets the split point there. The lead is LEAD OCTAVE (+1) up. CHORD CHANGE's
SPLIT is now STAGGER."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0
LEAD_V = (1, 2, 6)                 # GB pulse 1, NES pulse 1, SID 3


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def rows(c):
    return [c.screen_row(r) for r in range(25)]


def sel(c, label):
    for _ in range(40):
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


def held(c):
    return c.v("heldList", 8)[:c.v("heldCount")]


def cv_tap(c):
    c._raw_press("cbm", ms=30)
    c._raw_tap("v", ms=40)
    c._raw_release("cbm", ms=40)


def cv_hold(c):
    c._raw_press("cbm", ms=30)
    c._raw_press("v", ms=40)


def cv_let_go(c):
    c._raw_release("v", ms=30)
    c._raw_release("cbm", ms=40)


def lead_notes(c):
    vn = c.v("vNote", 9)
    return [vn[i] for i in LEAD_V]


c = C64(channels=None)
c.run_ms(400)
check("header V0.35", "V0.35" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- C= + V: KEY
cv_tap(c)
c.run_ms(100)
check("C= + V: SPLIT KEY", c.v("clMode") == 1, c.v("clMode"))
check("row 3: the lead's patch and SPLIT AT C4 (the overlay's middle key)",
      c.screen_row(3).startswith("LEAD    DUTY LEAD") and "SPLIT AT C4" in c.screen_row(3), c.screen_row(3))
c.press("q", "e", "t", ms=150)
check("keys below the split: the chord (C E G)", held(c) == [48, 52, 55] and c.v("leadNote") == 255, held(c))
c.press("i", ms=150)
check("a key from the split up: the lead, an octave up (C5 = 72) on its voices",
      c.v("leadNote") == 72 and lead_notes(c) == [72, 72, 72] and held(c) == [48, 52, 55], (c.v("leadNote"), lead_notes(c)))
c.press("o", ms=150)
check("... another: the lead moves to it (D5 + 12)", c.v("leadNote") == 74, c.v("leadNote"))
c.release("o", "i", ms=150)
check("lead keys let go: no lead, the chord plays on", c.v("leadNote") == 255 and held(c) == [48, 52, 55])
c.release("q", "e", "t", ms=150)
check("chord keys let go: silent (KEY has no latch)", held(c) == [], held(c))

c.tap("f1", ms=100)                          # an octave up
check("F1: the split stays on the same key (SPLIT AT C5 now)", "SPLIT AT C5" in c.screen_row(3), c.screen_row(3))
c.press("u", ms=120)
c.press("i", ms=120)
check("... u below it still the chord, i the lead", held(c) == [71] and c.v("leadNote") == 84, (held(c), c.v("leadNote")))
c.release("u", "i", ms=150)
c.tap("f3", ms=100)

# ---------------------------------------------------------------- C= + V held + a key: the split point
cv_hold(c)
c.press("e", ms=80)
check("C= + V held + E: no note plays", held(c) == [] and c.v("leadNote") == 255)
c.release("e", ms=40)
cv_let_go(c)
c.run_ms(100)
check("... the split is at E now (still KEY: letting go doesn't step SPLIT)",
      c.v("splitKey") == 4 and c.v("clMode") == 1 and "SPLIT AT E3" in c.screen_row(3), (c.v("splitKey"), c.screen_row(3)))
c.press("w", ms=120)
c.press("e", ms=120)
check("D: the chord, E: the lead", held(c) == [50] and c.v("leadNote") == 64, (held(c), c.v("leadNote")))
c.release("w", "e", ms=150)

# ---------------------------------------------------------------- MIDI: by note as sent
c.midi_in(0x90, 50, 100, ms=100)
c.midi_in(0x90, 64, 100, ms=100)
check("MIDI in: under SPLIT NOTE (C4) the chord, from it up the lead (+12)", held(c) == [50] and c.v("leadNote") == 76,
      (held(c), c.v("leadNote")))
c.midi_in(0x80, 64, 0, ms=50)
c.midi_in(0x80, 50, 0, ms=100)
cv_hold(c)
c.midi_in(0x90, 55, 100, ms=60)
c.midi_in(0x80, 55, 0, ms=40)
cv_let_go(c)
check("C= + V held + a MIDI note (G3): SPLIT NOTE there, nothing played", c.v("splitNote") == 55 and held(c) == []
      and c.v("splitKey") == 4, c.v("splitNote"))
c._raw_press("cbm", ms=30); c._raw_tap(":", ms=40); c._raw_release("cbm", ms=40)     # MIDI IN OCTAVE +1
c.midi_in(0x90, 54, 100, ms=100)
c.midi_in(0x90, 55, 100, ms=100)
check("MIDI IN OCTAVE +1: the split stays at the note sent (54: chord at 66, 55: lead at 67 + 12)",
      held(c) == [66] and c.v("leadNote") == 79, (held(c), c.v("leadNote")))
c.midi_in(0x80, 55, 0, ms=50)
c.midi_in(0x80, 54, 0, ms=100)
c._raw_press("cbm", ms=30); c._raw_tap(";", ms=40); c._raw_release("cbm", ms=40)

# ---------------------------------------------------------------- the menu
c.tap("return", ms=60)
sel(c, "PLAYING")
c.tap("return", ms=60)
check("PLAYING: SPLIT (C= V) KEY, SPLIT KEY E3, SPLIT NOTE (MIDI) G3, LEAD OCTAVE +1",
      "KEY" in row_of(c, "SPLIT (C= V)") and "E3" in row_of(c, "SPLIT KEY") and "G3" in row_of(c, "SPLIT NOTE (MIDI)")
      and "+1" in row_of(c, "LEAD OCTAVE"), [r for r in rows(c) if "SPLIT" in r or "LEAD" in r])
sel(c, "CHORD CHANGE")
for _ in range(3):
    c.tap("f7", ms=30)
check("CHORD CHANGE: STAGGER (was SPLIT)", "STAGGER" in row_of(c, "CHORD CHANGE"), row_of(c, "CHORD CHANGE"))
c.tap("f5", ms=30); c.tap("f5", ms=30); c.tap("f5", ms=30)
sel(c, "SPLIT KEY")
c.tap("f7", ms=40)
check("SPLIT KEY F7: F3", "F3" in row_of(c, "SPLIT KEY") and c.v("splitKey") == 5, row_of(c, "SPLIT KEY"))
sel(c, "LEAD OCTAVE")
c.tap("f5", ms=40)
check("LEAD OCTAVE F5: 0", row_of(c, "LEAD OCTAVE").rstrip().endswith("0") and c.v("leadOct") == 2, row_of(c, "LEAD OCTAVE"))
sel(c, "SPLIT (C= V)")
c.tap("f7", ms=40)
check("SPLIT LOW NOTE: the KEY rows go", "LOW NOTE" in row_of(c, "SPLIT (C= V)") and row_of(c, "SPLIT KEY") == ""
      and row_of(c, "LEAD OCTAVE") == "", [r for r in rows(c) if r.strip()][-4:])
c.tap("f5", ms=40)
back(c, 2)
c.press("w", ms=100)
c.press("t", ms=100)
check("LEAD OCTAVE 0: the lead where it's played (G3)", c.v("leadNote") == 55 and held(c) == [50], (c.v("leadNote"), held(c)))
c.release("w", "t", ms=150)

# ---------------------------------------------------------------- C= + V steps round
cv_tap(c)
check("C= + V: LOW NOTE (row 3: no split shown)", c.v("clMode") == 2 and "SPLIT AT" not in c.screen_row(3), c.screen_row(3))
cv_tap(c)
check("C= + V: LATCH 3", c.v("clMode") == 3)
cv_tap(c)
c.run_ms(100)
check("C= + V: OFF (row 3 empty)", c.v("clMode") == 0 and c.screen_row(3).strip() == "", c.screen_row(3))
c.press("q", "i", ms=120)
check("... keys play as before", held(c) == [48, 60] and c.v("leadNote") == 255, held(c))
c.release("q", "i", ms=100)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
