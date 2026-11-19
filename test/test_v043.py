#!/usr/bin/env python3
"""Fat Chip 64 v0.43: the menu takes only the cursor keys, RETURN and
SHIFT + RETURN (the F keys keep their play jobs there); RANDOMIZE, not the
dice, on the help screens."""
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


def sel_row(c):
    return next((r for r in rows(c) if r.startswith("> ")), "")


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.menu_fkeys = False
c.run_ms(400)
check("header V0.43", "V0.43" in c.screen_row(0), c.screen_row(0))

c._raw_tap("return", ms=100)
r = rows(c)
check("the menu's help lines: the cursor keys, RANDOMIZE", any("CRSR DOWN (SHIFT: UP): CHOOSE A LINE" in x for x in r)
      and any("CRSR RIGHT (SHIFT: LEFT): CHANGE IT" in x for x in r) and any("SHIFT+/: RANDOMIZE IT" in x for x in r)
      and not any("F1 / F3" in x or "DICE" in x for x in r), r[20:])
s0 = sel_row(c)
c._raw_tap("f3", ms=80)
check("F3 in the menu: no line change", sel_row(c) == s0, (s0, sel_row(c)))
c._raw_tap("crsrdown", ms=80)
s1 = sel_row(c)
check("CRSR DOWN: the next line", s1 != s0, (s0, s1))
c._raw_press("lshift", ms=10); c._raw_tap("crsrdown", ms=80); c._raw_release("lshift", ms=40)
check("SHIFT + CRSR DOWN: back up", sel_row(c) == s0, sel_row(c))

# a value: SPLIT's mode (PLAYING)
for _ in range(30):
    if sel_row(c).startswith("> PLAYING"):
        break
    c._raw_tap("crsrdown", ms=25)
c._raw_tap("return", ms=80)
for _ in range(40):
    if sel_row(c).startswith("> SPLIT ("):
        break
    c._raw_tap("crsrdown", ms=25)
m0 = c.v("clMode")
c._raw_tap("f7", ms=80)
check("F7 on a setting: it doesn't change", c.v("clMode") == m0, c.v("clMode"))
c._raw_tap("crsrright", ms=80)
check("CRSR RIGHT: it does", c.v("clMode") == (m0 + 1) % 4, c.v("clMode"))
c._raw_press("lshift", ms=10); c._raw_tap("crsrright", ms=80); c._raw_release("lshift", ms=40)
check("SHIFT + CRSR RIGHT: back", c.v("clMode") == m0, c.v("clMode"))
oct0 = c.v("octBase")
c._raw_tap("f1", ms=80)
check("F1 in the menu: its play job (an octave up)", c.v("octBase") == oct0 + 12, (oct0, c.v("octBase")))
c._raw_tap("f3", ms=80)

# the help page
c._raw_press("lshift", ms=10); c._raw_tap("return", ms=60); c._raw_release("lshift", ms=40)
for _ in range(30):
    if sel_row(c).startswith("> HELP"):
        break
    c._raw_tap("crsrdown", ms=25)
c._raw_tap("return", ms=100)
check("HELP: / RANDOM", any("/ RANDOM" in x for x in rows(c)) and not any("DICE" in x for x in rows(c)),
      [x for x in rows(c) if "/" in x][:2])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
