#!/usr/bin/env python3
"""Fat Chip 64 v0.50: every 2 s or so (nothing waiting for the Game Boy) the
Game Boy gets its channels (CC 113), the tuning (CC 103) and the sound's
status (CC 114 = 64 + the built-in sound, 127 CUSTOM), for a Game Boy
switched on late and for its cards' names (Fat Chip GB v0.11). The status
also follows a sound sent as CCs, in either DEVICES > GAME BOY setting."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
CPS = 985248


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def sound(c, i):
    T = 0xCF80
    a = c.sym["SoundSet"]
    cpu = c.cpu
    saved = (cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p)
    for k, b in enumerate([0x20, a & 255, a >> 8, 0x4C, (T + 3) & 255, (T + 3) >> 8]):
        c.raw[T + k] = b
    t0 = cpu.processorCycles
    cpu.pc, cpu.x = T, i
    while cpu.pc != T + 3:
        c.step()
    cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p = saved
    c.run_ms(300)
    return t0


def gbcc(c, t0, ch=None):
    gb = c.v("gbBase")
    return [((t - t0) * 1000 // CPS, a, b) for t, s, a, b in c.midi()
            if t >= t0 and s & 0xF0 == 0xB0 and (s & 15) == (gb if ch is None else ch)]


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(500)
check("header V0.50", "V0.50" in c.screen_row(0), c.screen_row(0))
gb = c.v("gbBase")
sound(c, 4)
t0 = c.cpu.processorCycles
c.run_ms(5000)
m = gbcc(c, t0)
hb = [x for x in m if x[1] in (113, 103, 114)]
st = [b for _, a, b in hb if a == 114]
check("idle 5 s: the channels, tuning and status about every 2 s", 2 <= len(st) <= 3 and
      [b for _, a, b in hb if a == 113] == [64 + gb] * len(st) and len([1 for x in hb if x[1] == 103]) == len(st), hb)
check("... the status: 64 + the sound (WHISTLE 4)", st and all(b == 68 for b in st), st)
ts = [t for t, a, b in hb if a == 114]
check("... spaced about 2 s", all(1900 <= b - a <= 2400 for a, b in zip(ts, ts[1:])), ts)

# while notes are streaming, it waits for a quiet moment
c.set("gbFc", 1)
t0 = sound(c, 13)
m = gbcc(c, t0)
check("OTHER (MGB): the CCs, then the status (64 + 13) last", m and m[-1][1:] == (114, 64 + 13) and len(m) > 10, m[-3:])
c.set("gbFc", 0)
t0 = sound(c, 4)
check("FAT CHIP GB: just CC 114 4 (no status after it)", [x[1:] for x in gbcc(c, t0)] == [(114, 4)], gbcc(c, t0))

# an edited sound: its name gets a *: CUSTOM
c.raw[c.sym["patchName"] + 15] = ord("*")
c.set("gbFc", 1)
t0 = sound(c, 4) if False else c.cpu.processorCycles
c.run_ms(2600)
st = [b for _, a, b in gbcc(c, t0) if a == 114]
check("a built-in sound edited (* on its name): status 127 (CUSTOM)", st and st[-1] == 127, st)
c.set("gbFc", 0)

# a patch from Chip Lab (SysEx): CUSTOM
p = dict(gen_patches.PATCHES[4])
t0 = c.cpu.processorCycles
c.midi_in(*gen_patches.sysex(p), ms=400)
st = [b for _, a, b in gbcc(c, t0) if a == 114]
check("a patch received over SysEx: its CCs, then status 127", st and st[-1] == 127 and c.v("soundMode") == 255, st)

# randomized: CUSTOM
sound(c, 2)
c._raw_tap("/", ms=100)
t0 = c.cpu.processorCycles
c.run_ms(2600)
st = [b for _, a, b in gbcc(c, t0) if a == 114]
check("RANDOMIZE: status 127", st and st[-1] == 127, st)

# ---------------------------------------------------------------- One Key Play: not latched, not arpeggiated
c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
c.set("okpOn", 1)
c.set("playMode", 1)
c.set("monoMode", 0)
c._raw_tap("l", ms=60)                                       # latch
c.press("q", ms=200)
c.release("q", ms=300)
chord = c.v("heldList", 8)[:c.v("heldCount")]
c._raw_press("crsrdown", ms=150)
okp = [n for n in c.v("okpNotes", 2) if n != 255]
with_okp = c.v("heldList", 8)[:c.v("heldCount")]
check("latched chord + One Key Play held: both sound", all(n in with_okp for n in chord + okp) and okp, (chord, okp, with_okp))
c._raw_release("crsrdown", ms=300)
after = c.v("heldList", 8)[:c.v("heldCount")]
check("let go of the cursor key: One Key Play's notes stop, the latched chord stays", after == chord, (after, chord))
c._raw_tap("l", ms=60)
c.run_ms(300)


def arp_notes(c, ms):
    seen = set()
    for _ in range(ms // 10):
        c.run_ms(10)
        seen.add(c.v("arpNote"))
    return seen


for mode, name in ((1, "UNISON"), (2, "SPARKLE")):
    c.set("arpMode", mode)
    c.press("q", ms=100)
    c._raw_press("crsrdown", ms=50)
    okp = [n for n in c.v("okpNotes", 2) if n != 255]
    chord = c.v("okpChord", 8)[:c.v("okpChordN")]
    seen = arp_notes(c, 1500)
    want = [c.v("vWant", 9)[v] for v in range(9)]
    check(f"arp {name}: it steps through the chord only, not One Key Play's notes", seen <= set(chord) and len(seen) >= 2 and not (set(okp) & seen),
          (sorted(seen), chord, okp))
    vn = [c.v("vNote", 9)[v] for v in range(9)]
    check(f"... One Key Play's notes still sound", all(n in vn for n in okp), (okp, vn))
    c._raw_release("crsrdown", ms=50)
    c.release("q", ms=300)
    c._raw_press("crsrdown", ms=200)
    check(f"... One Key Play alone doesn't start the arp", c.v("arpRunning") == 0, c.v("arpRunning"))
    c._raw_release("crsrdown", ms=300)
c.set("arpMode", 0)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
