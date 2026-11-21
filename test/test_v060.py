#!/usr/bin/env python3
"""Fat Chip 64 v0.60: room for the beats. The beats' kits, names and steps
live in the RAM under the I/O at $D000 (src/beatsio.asm); choosing a beat
copies it into kitBuf / nameBuf / beatBuf with the I/O switched out for a
moment. crunch.py packs that data too and lays the packed $E000 tables and
$D000 data in the room the packed code tail needs, so every page packed gains."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim import C64  # noqa: E402
import gen_beats  # noqa: E402

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


c = C64(channels=None)
s = c.sym
check("the $D000 data sits below $DE00 (clear of the ACIA Nmi reads)", s["ioStart"] == 0xD000 and s["ioEnd"] <= 0xDE00,
      hex(s["ioEnd"]))

beats = gen_beats.BEATS
ok_all = True
for i, b in enumerate(beats):
    if i:
        mod(c, "runstop", ";")                            # (the next beat)
    c.run_ms(30)
    if c.v("beatSel") != i:
        ok_all = False
        print("  (couldn't pick beat", i, ")")
        continue
    p = c.raw[s["beatIoLo"] + i] | c.raw[s["beatIoHi"] + i] << 8
    n = c.raw[s["beatSize"] + i]                          # (v0.61: kit, name and lanes)
    want = bytes(c.under[p - 0xD000:p - 0xD000 + n])
    got = bytes(c.raw[s["kitBuf"]:s["kitBuf"] + n])
    ok = want == got and got[12:20].decode().rstrip() == b["name"]
    ok_all &= ok
    if not ok:
        print("  beat", i, got[12:21])
check("each beat's kit, name and steps are copied out when it's chosen", ok_all)
check("the I/O is switched back on after", c.raw[1] == 0x35, hex(c.raw[1]))
check("the play screen names the beat", beats[c.v("beatSel")]["name"] in c.screen_row(12), c.screen_row(12))

# the beat plays from the copy (RETURN... RUN/STOP tapped starts it)
mod(c, "runstop", ";")                                # (back round to the first)
c._raw_tap("runstop", ms=40)
c.run_ms(600)
hits = [m for m in c.midi() if (m[1] & 0xF0) == 0x90 and m[3]]
check("the first beat plays from the copy (drum notes go out)", c.v("beatRun") and len(hits) > 3, len(hits))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
