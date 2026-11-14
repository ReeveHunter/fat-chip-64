#!/usr/bin/env python3
"""Fat Chip 64 v0.19: the built-in patches come from patch/patches.json, in
the shared units; the Game Boy and NES follow each patch's main envelope."""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0
ROOT = os.path.join(os.path.dirname(__file__), "..")


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_effects.py")], capture_output=True, text=True)
check("effects.json and patches.json check out", r.returncode == 0, r.stdout.strip()[-120:])
tab = open(os.path.join(ROOT, "src", "soundtab.asm")).read()
subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_patches.py")], capture_output=True)
check("soundtab.asm is up to date with patches.json", open(os.path.join(ROOT, "src", "soundtab.asm")).read() == tab)

c = C64(channels=None)
c.run_ms(400)
check("header V0.36", "V0.36" in c.screen_row(0), c.screen_row(0))


def gb_ccs(c, t0):
    return {(s & 15, a): b for _, s, a, b in c.midi(since=t0) if s & 0xF0 == 0xB0 and (s & 15) in (10, 11, 12)}


# FAT: SID release 750 ms -> Game Boy release 3 (15 steps of 3/64 s = 0.7 s)
t0 = c.cpu.processorCycles
c.midi_in(0xC0, 1, ms=300)
c.midi_in(0xC0, 0, ms=300)
cc = gb_ccs(c, t0)
check("FAT: Game Boy release 3 on every channel (CC72 48), like the SID's 750 ms", all(cc.get((ch, 72)) == 48 for ch in (10, 11, 12)), cc)

# a NES note rings out after the key is let go
c.press("q", ms=300)
t0 = c.cpu.processorCycles
c.release("q", ms=1000)
offs = [round((t - t0) / CYCLES_PER_MS) for t, s, a, b in c.midi(since=t0) if s & 0xF0 == 0x80 and s & 15 in (0, 1)]
check("FAT: the NES pulses fade, note-offs after about 0.6 s", offs and min(offs) > 400, offs)

# ECHO PLUCK (sustain 0): the Game Boy falls away like the SID
t0 = c.cpu.processorCycles
c.midi_in(0xC0, 17, ms=300)
cc = gb_ccs(c, t0)
check("ECHO PLUCK: Game Boy decay 4 (CC75 64), the SID's 750 ms to silence", cc.get((10, 75)) == 64, cc)

# glide that's only on some chips: PADS glides on the Game Boy, not the SID
c.midi_in(0xC0, 1, ms=300)
check("PADS: GLIDE limited to the Game Boy: no SID glide", c.v("sndGlide") == 0 and c.v("gbGl1") > 0)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
