#!/usr/bin/env python3
"""Fat Chip 64 v0.37: RESTORE cycles the video modes (NORMAL, VISUALIZER,
SCREENS OFF); F5 Fat Bass on / off; F7 the arp on / off."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402
C64.fkeys_036 = False                         # (this test speaks v0.37's keys)

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def restore(c):
    c.restore()
    c.run_ms(120)


def shown(c):
    return bool(c.raw[0xD011] & 0x10)


c = C64(channels=None)
c.run_ms(400)
check("header V0.37", "V0.37" in c.screen_row(0), c.screen_row(0))
check("NORMAL at start: the play screen, shown", c.v("vidState") == 0 and shown(c) and c.v("vizOn") == 0)

t0 = c.cpu.processorCycles
restore(c)
check("RESTORE: VISUALIZER (GLITCH), the screen still on", c.v("vidState") == 1 and c.v("vizOn") == 2 and shown(c))
c.press("q", "e", "t", ms=400)
c.release("q", "e", "t", ms=100)
check("... the header's gone (the visualizer has the screen)", "FAT CHIP" not in c.screen_row(0), c.screen_row(0))
restore(c)
gb = [(s, a, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 112]
check("RESTORE: SCREENS OFF (the C64 blanked, the Game Boy's off with CC 112)", c.v("vidState") == 2 and not shown(c)
      and c.v("vizOn") == 0 and gb and gb[-1][2] == 1, gb)
restore(c)
gb = [(s, a, b) for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 112]
check("RESTORE: NORMAL again, the play screen back", c.v("vidState") == 0 and shown(c) and "FAT CHIP" in c.screen_row(0)
      and gb[-1][2] == 0, (c.screen_row(0), gb))

c.tap("return", ms=80)
restore(c)
check("in the menu: RESTORE skips the visualizer (screens off)", c.v("vidState") == 2 and not shown(c) and c.v("vizOn") == 0)
restore(c)
check("... and back", c.v("vidState") == 0 and shown(c))
c._raw_press("lshift", ms=8); c._raw_tap("return", ms=60); c._raw_release("lshift", ms=80)

# F5: Fat Bass
f0 = c.v("fatBass")
c.tap("f5", ms=80)
check("F5: Fat Bass toggles", c.v("fatBass") == 1 - f0, (f0, c.v("fatBass")))
c.tap("f5", ms=80)
check("F5 again: back", c.v("fatBass") == f0)

# F7: the arp
a0 = c.v("arpMode")
c.tap("f7", ms=80)
check("F7: the arp toggles (was F5)", c.v("arpMode") != a0 and c.v("vizOn") == 0, (a0, c.v("arpMode")))
c.tap("f7", ms=80)
check("F7 again: off", c.v("arpMode") == a0)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
