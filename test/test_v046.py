#!/usr/bin/env python3
"""Fat Chip 64 v0.46: a built-in sound, as it is, goes to Fat Chip GB as one
CC 114 (the sound's number) instead of about 45 CCs; DEVICES > GAME BOY >
OTHER (MGB), something in play that changes the Game Boy's part (a lock, a
held effect, DRONE) or an edited sound still sends the CCs."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def sound(c, i):
    """SoundSetX's path for sound i (a JSR SoundSetX trampoline)."""
    T = 0xCF80
    a = c.sym["SoundSetX"] if "SoundSetX" in c.sym else c.sym["SoundSet"]
    cpu = c.cpu
    saved = (cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p)
    for k, b in enumerate([0x20, a & 255, a >> 8, 0x4C, (T + 3) & 255, (T + 3) >> 8]):
        c.raw[T + k] = b
    t0 = cpu.processorCycles
    cpu.pc, cpu.x = T, i
    while cpu.pc != T + 3:
        c.step()
    cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p = saved
    c.run_ms(400)
    gb = c.v("gbBase")
    return [(s & 15, d1, d2) for t, s, d1, d2 in c.midi()
            if t >= t0 and s & 0xF0 == 0xB0 and 0 <= (s & 15) - gb < 3
            and d1 not in (103, 113) and not (d1 == 114 and d2 >= 64)]    # (v0.50: the sync and status: test_v050)


c = C64(channels=None)
c.run_ms(500)
check("header V0.50", "V0.50" in c.screen_row(0), c.screen_row(0))
check("DEVICES > GAME BOY: FAT CHIP GB by default", c.v("gbFc") == 0)
gb = c.v("gbBase")

m = sound(c, 4)
check("a built-in sound: one CC 114 = its number to the Game Boy, nothing else", m == [(gb, 114, 4)], m[:6])
check("... it's the sound now", c.v("soundMode") == 4)
m = sound(c, 13)
check("another: CC 114 13", m == [(gb, 114, 13)], m[:6])

c.set("gbFc", 1)
m = sound(c, 4)
check("GAME BOY: OTHER (MGB): the CCs, no CC 114", len(m) > 10 and not any(d1 == 114 for _, d1, _ in m), len(m))
full = m
c.set("gbFc", 0)
m = sound(c, 13)
m = sound(c, 4)
check("... back to FAT CHIP GB: CC 114 again", m == [(gb, 114, 4)], m[:6])
c.set("gbFc", 1)
m = sound(c, 13)
m = sound(c, 4)
check("the dry run kept the cache right: OTHER after a CC 114 sends what it would have",
      sorted(m) == sorted(full), (len(m), len(full)))
c.set("gbFc", 0)

c.set("vibLock", 1)
m = sound(c, 13)
check("a lock in play (VIBRATO): the CCs", len(m) > 3 and not any(d1 == 114 for _, d1, _ in m), m[:4])
c.set("vibLock", 0)
m = sound(c, 4)
check("... let go: CC 114 again", m == [(gb, 114, 4)], m[:6])


c.set("monoLock", 2)                      # MONO / POLY: POLY (GLIDE BASS is a MONO sound)
m = sound(c, 13)
check("menu POLY on a MONO sound: CC 114, then legato off again (its copy has it on)",
      m == [(gb, 114, 13)] + [(gb + v, 68, 0) for v in range(3)], m)
c.set("monoLock", 0)
m = sound(c, 4)
check("... the sound's own: just CC 114", m == [(gb, 114, 4)], m)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
