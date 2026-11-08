#!/usr/bin/env python3
"""Fat Chip 64 v0.10: = OFF / SMART, faster FREE arp (queues skip, never
hang), : ; arp speed, , . SPACE modes and the SPACE bend."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

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


def bends(c, since, ch=None):
    return [(round((cyc - since) / CYCLES_PER_MS), s & 15, ((b << 7) | a)) for cyc, s, a, b in c.midi(since=since)
            if (s & 0xF0) == 0xE0 and (ch is None or s & 15 == ch)]


def sid_freq(c, v):
    return c.raw[0xD400 + 7 * v] | c.raw[0xD401 + 7 * v] << 8


def p_tri(n):
    return round(1710 * 0.5 ** ((n - 36) / 12))


GB, NES = (0, 1, 2), (5, 6, 7)

c = C64()
c.run_ms(200)
check("startup: no bends sent", bends(c, 0) == [])
check("= toggles OFF -> SMART -> OFF", True)
c.tap("=", ms=60)
a = c.v("latch")
c.tap("=", ms=60)
check("= : SMART then OFF", (a, c.v("latch")) == (1, 0), (a, c.v("latch")))

# ---------------------------------------------------------------- fastest arp
c.tap("a", ms=40)                           # UNISON
for _ in range(4):
    c.tap(";", ms=30)                       # 30 -> 25 20 15 10
c.run_ms(80)
check("; down to 10 MS", c.v("freeIdx") == 0 and "10MS" in c.screen_row(19).replace(" ", ""), c.screen_row(19))
c.tap(";", ms=30)
check("; stops at 10 MS", c.v("freeIdx") == 0)
t0 = c.cpu.processorCycles
peak = [0, 0]
c.press("q", "e", "t", "u")                 # C E G B
for _ in range(150):                        # 3 s at 10 ms steps
    c.run_ms(20)
    peak[0] = max(peak[0], (c.v("gbqHead") - c.v("gbqTail")) & 63)
    peak[1] = max(peak[1], (c.v("nesqHead") - c.v("nesqTail")) & 63)
sid_ons = [x for x in c.midi(since=t0)]
check("10 ms arp: the queues stay short (no overflow)", peak[0] < 20 and peak[1] < 20, peak)
gb_ons = [x for x in c.midi(since=t0) if x[1] & 0xF0 == 0x90 and x[1] & 15 == 0 and x[3]]
check("10 ms arp: the Game Boy still steps (skipping what it can't keep up with)", len(gb_ons) > 40, len(gb_ons))
c.release("q", "e", "t", "u")
c.run_ms(400)
on = notes_on(c.midi())
check("10 ms arp: released = nothing left sounding anywhere", on == {}, on)
check("10 ms arp: every voice off", all(v == 255 for v in c.v("vOut", 9)) and all(v == 255 for v in c.v("vNote", 9)))
c.tap("a", ms=30); c.tap("a", ms=30)        # arp off

# ---------------------------------------------------------------- SPACE modes
c.run_ms(150)
check("SPACE: BEND DOWN by default (v0.13)", "<> SPACE BEND DN" in c.screen_row(22), c.screen_row(22))
c.tap(".", ms=150)
check(". : SPACE BEND UP", c.v("spaceAct") == 2 and "SPACE BEND UP" in c.screen_row(22), c.screen_row(22))
c.tap(",", ms=10)
c.tap(",", ms=150)
check(", , : MUTE", c.v("spaceAct") == 0 and "SPACE MUTE" in c.screen_row(22), c.screen_row(22))
c.tap(",", ms=10)
c.tap(",", ms=150)
check(", , : wraps to NOTHING, then NEXT SOUND", c.v("spaceAct") == 14, c.v("spaceAct"))
c.set("spaceAct", 1)                        # BEND DOWN

c.press("w", ms=200)                        # D: SID 38+12.. (whatever), GB, NES
base = [sid_freq(c, v) for v in range(3)]
on = notes_on(c.midi())
t0 = c.cpu.processorCycles
c.press("space", ms=500)
mid = c.v("bendLvl")
check("bend: half way after 0.5 s", 110 <= mid <= 135, mid)
check("bend: SPACE doesn't mute in BEND DOWN", c.raw[0xD418] & 15 == 15 and notes_on(c.midi()) == on)
c.run_ms(700)
check("bend: all the way after about 1 s", c.v("bendLvl") == 255)
ratio = [sid_freq(c, v) / base[v] for v in range(3) if base[v]]
check("bend: SID 2 semitones down (x 0.891)", ratio and all(abs(r - 0.8909) < 0.004 for r in ratio), ratio)
b = bends(c, t0)
gbv = [x for x in b if x[1] in GB]
check("bend: Game Boy channels end at 8192 - 2/12 of 8192 (range 12)", all(gbv and [x for x in gbv if x[1] == ch][-1][2] == 8192 - 1366 for ch in GB), gbv[-3:])
gaps = sorted({x[0] for x in gbv if x[1] == 0})
gaps = [y - x for x, y in zip(gaps, gaps[1:])]
check("bend: MIDI bends about every 20 ms, not faster", gaps and min(gaps) >= 15 and max(gaps) < 40, gaps)
check("bend: falling all the way", [x[2] for x in gbv if x[1] == 0] == sorted([x[2] for x in gbv if x[1] == 0], reverse=True))
for ch, tri in ((5, False), (6, False), (7, True)):
    n = on.get(ch)
    last = [x for x in b if x[1] == ch][-1][2]
    want = 8192 - (((p_tri(n) * 2006) >> (13 if tri else 12)) & ~3)     # 2006 = 2 (2^(1/6) - 1) x 8192
    check(f"bend: MidiNES ch {ch + 1} (note {n}) bent by its note's amount", last == want, (last, want))

# a new NES note while bent gets its bend first
t1 = c.cpu.processorCycles
c.release("w", ms=60)
c.press("y", ms=100)
m = [(x[1] & 0xF0, x[2], x[3]) for x in c.midi(since=t1) if x[1] & 15 == 5]
i_on = next(i for i, x in enumerate(m) if x[0] == 0x90 and x[2])
n = m[i_on][1]
want = 8192 - (((p_tri(n) * 2006) >> 12) & ~3)
pre = [x for x in m[:i_on] if x[0] == 0xE0]
check("bend: a new NES note gets its own bend before the note-on",
      pre and ((pre[-1][2] << 7) | pre[-1][1]) == want, (m[:i_on + 1], want))

t1 = c.cpu.processorCycles
c.release("space", ms=300)
mid = c.v("bendLvl")
check("bend: let go, half way back after 0.25 s", 100 <= mid <= 150, mid)
c.run_ms(400)
check("bend: back to centre after 0.5 s", c.v("bendLvl") == 0)
base2 = [sid_freq(c, v) for v in range(3)]
b = bends(c, t1)
check("bend: every Game Boy / NES channel ends centred",
      all([x for x in b if x[1] == ch][-1][2] == 8192 for ch in GB + NES), b[-6:])
c.press("space", ms=600)
c.release("space", ms=10)                   # coming back up...
c.press("lshift", ms=10); c.tap("f7", ms=40); c.release("lshift", ms=10)   # ...panic
c.run_ms(250)                               # (v0.12: the Game Boy's sound setup after panic is longer)
b = bends(c, c.cpu.processorCycles - 310 * CYCLES_PER_MS)
check("panic during a bend: straight back to centre", c.v("bendLvl") == 0 and b and all(x[2] == 8192 for x in b[-6:]), b[-6:])
c.release("y", ms=40)
c.set("spaceAct", 0)
check("SPACE set to MUTE", c.v("spaceAct") == 0)
c.press("w", ms=100)
c.press("space", ms=60)
check("MUTE: SPACE flips the mute", c.raw[0xD418] & 15 == 0 and notes_on(c.midi()) == {})
c.release("space", ms=60)
c.release("w", ms=60)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
