#!/usr/bin/env python3
"""Fat Chip 64 v0.45: C= + the cursor keys edit the last effect as the menu
does (CRSR DOWN its next setting, SHIFT: the one before; CRSR RIGHT its
value, SHIFT: back); C= + RETURN opens the menu on that effect's page at
that setting, and SHIFT + RETURN there goes straight back to playing."""
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
    c._raw_release(m, ms=150)                                # (and row 14 redrawn)


def mod2(c, m, k, ms=40):                                    # C= + SHIFT + k
    c._raw_press(m, ms=20)
    c._raw_press("lshift", ms=20)
    c._raw_tap(k, ms=ms)
    c._raw_release("lshift", ms=20)
    c._raw_release(m, ms=150)


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.menu_fkeys = False
c.run_ms(400)
check("header V0.52", "V0.52" in c.screen_row(0), c.screen_row(0))

mod(c, "cbm", "v")                                           # VIBRATO: DEPTH
r0 = c.screen_row(14)
check("C= + V: VIBRATO, DEPTH on row 14", "VIBRATO" in r0 and "DEPTH" in r0, r0)
mod(c, "cbm", "crsrdown")
check("C= + CRSR DOWN: its next setting (RATE)", "RATE" in c.screen_row(14), c.screen_row(14))
mod2(c, "cbm", "crsrdown")
check("C= + SHIFT + CRSR DOWN: back (DEPTH)", "DEPTH" in c.screen_row(14), c.screen_row(14))
mod2(c, "cbm", "crsrdown")
check("... and round to its last setting", "DEPTH" not in c.screen_row(14) and c.v("fxParam") > 0, c.screen_row(14))
mod(c, "cbm", "crsrdown")
v0 = c.screen_row(14)[29:].strip()
mod(c, "cbm", "crsrright")
v1 = c.screen_row(14)[29:].strip()
mod2(c, "cbm", "crsrright")
v2 = c.screen_row(14)[29:].strip()
check("C= + CRSR RIGHT: DEPTH up; SHIFT: back down", v1 != v0 and v2 == v0, (v0, v1, v2))
check("C= + CRSR: no One Key Play (nothing played)", c.v("okpCount") == 0, c.v("okpCount"))

mod(c, "cbm", "crsrdown")                                    # RATE
mod(c, "cbm", "return")
rows = [c.screen_row(r) for r in range(25)]
check("C= + RETURN: the menu, VIBRATO's page, on RATE", c.v("menuOn") == 1 and any("VIBRATO" in r for r in rows[:2])
      and any(r.startswith("> RATE") for r in rows), rows[:8])
c._raw_press("lshift", ms=10); c._raw_tap("return", ms=80); c._raw_release("lshift", ms=60)
check("SHIFT + RETURN there: straight back to playing", c.v("menuOn") == 0, c.v("menuOn"))
c._raw_tap("return", ms=80)
c._raw_press("lshift", ms=10); c._raw_tap("return", ms=80); c._raw_release("lshift", ms=60)
check("(the menu opened with RETURN closes from its main page as before)", c.v("menuOn") == 0)

# C= + : / ; : which effect, without switching it
c.set("fxFocus", 0)
on0 = c.v("livePatch", 128)
mod(c, "cbm", ";")
check("C= + ; with none chosen: the envelope first (row 14)", c.v("fxFocus") == c.sym["FXI_ENV"] + 1 and "ENVELOPE" in c.screen_row(14),
      c.screen_row(14))
mod(c, "cbm", ";")
check("C= + ; : the next (BEND IN), not switched on (row 14 dark grey)", c.v("fxFocus") == c.sym["FXI_PENV"] + 1
      and c.raw[0xD800 + 14 * 40 + 4] & 15 == 11 and c.v("livePatch", 128) == on0, c.screen_row(14))
mod(c, "cbm", ":", ":")
check("C= + : twice: back past the envelope to the arp (round)", c.v("fxFocus") == c.sym["FOCUS_ARP"], c.v("fxFocus"))
mod(c, "cbm", ";")
check("C= + ; from the arp: the envelope", c.v("fxFocus") == c.sym["FXI_ENV"] + 1)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
