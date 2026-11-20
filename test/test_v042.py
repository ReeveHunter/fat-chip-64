#!/usr/bin/env python3
"""Fat Chip 64 v0.42: WARBLE on the SID and NES (a slow random drift, each
voice its own); BEND IN's CLICK SHORT / LONG; TREMOLO's PUMP and GATEs are
SHAPEs; DRONE: every voice glides slowly to the new drone (no new attacks),
voice-led like Stumped's pads, the Game Boy at its slowest glide."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
P = gen_patches.PATCHES


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def sid_f(c, v=0):
    return c.raw[0xD400 + 7 * v] | c.raw[0xD401 + 7 * v] << 8


def send(c, base, **fx):
    p = copy.deepcopy(P[base])
    p["fatBass"] = 0
    for k in ("detune", "warble", "vibrato", "glide"):
        p["fx"].pop(k, None)
    for k, v in fx.items():
        p["fx"][k] = v
    n0 = c.v("sxCount")
    c.midi_in(*gen_patches.sysex(p), ms=200)
    assert c.v("sxCount") == (n0 + 1) & 255, "SysEx not taken"


c = C64(channels=None)
c.keys_039 = False
c.fkeys_036 = False
c.run_ms(400)
check("header V0.51", "V0.51" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- WARBLE: SID
send(c, 2, warble={"amount": 25, "speed": 127})
check("WARBLE 25 cents: sndWarbA about 25 x 2.37, the SID and NES on", abs(c.v("sndWarbA") - 59) <= 1 and c.v("warbChips") == 3,
      (c.v("sndWarbA"), c.v("warbChips")))
for n in (48, 52, 55):
    c.midi_in(0x90, n, 100, ms=20)
c.run_ms(200)
fs = [[], [], []]
for _ in range(80):
    c.run_ms(25)
    for v in range(3):
        fs[v].append(sid_f(c, v))
spans = [max(f) / min(f) for f in fs]
check("SID: each voice's pitch drifts (more than 10 cents), never past 25", all(2 ** (10 / 1200) < s < 2 ** (52 / 1200) for s in spans),
      [round(1200 * __import__("math").log2(s)) for s in spans])
rel = [[a / b for a, b in zip(fs[0], fs[1])]]
check("... each its own (voice 1 against voice 2 isn't fixed)", max(rel[0]) / min(rel[0]) > 2 ** (5 / 1200))

# ---------------------------------------------------------------- WARBLE: NES
t0 = c.cpu.processorCycles
c.run_ms(1500)
bends = {}
for t, s, a, b in c.midi():
    if t >= t0 and s & 0xF0 == 0xE0:
        bends.setdefault(s & 15, set()).add(b << 7 | a)
nesb = [len(v) for ch, v in bends.items() if ch == c.v("nesBase") or ch == c.v("nesBase") + 1]
check("NES: its pulses get a stream of bends (the drift), with no vibrato in the patch", nesb and max(nesb) >= 4, bends.keys())
for n in (48, 52, 55):
    c.midi_in(0x80, n, 0, ms=10)
c.run_ms(400)

# ---------------------------------------------------------------- CLICK LONG
send(c, 2, penv={"amount": 0, "time": 150, "click": 2})
c.midi_in(0x90, 48, 100, ms=100)
w100 = c.raw[0xD404]
c.run_ms(150)
w250 = c.raw[0xD404]
check("CLICK LONG (TIME 150 MS): noise still at 100 ms, the patch's waveform by 250", w100 & 0xF0 == 0x80 and w250 & 0xF0 == 0x40,
      (hex(w100), hex(w250)))
c.midi_in(0x80, 48, 0, ms=300)
send(c, 2, penv={"amount": 0, "time": 150, "click": 1})
c.midi_in(0x90, 48, 100, ms=60)
check("CLICK SHORT: 20 ms (gone by 60)", c.raw[0xD404] & 0xF0 == 0x40, hex(c.raw[0xD404]))
c.midi_in(0x80, 48, 0, ms=300)

# ---------------------------------------------------------------- TREMOLO SHAPE: PUMP
send(c, 18, tremolo={"depth": 100, "tremSync": 3, "shape": 6})
check("TREMOLO SHAPE PUMP: mode 1 (as v0.30's MODE PUMP)", c.v("nesTremMode") == 1 and c.v("nesTremShp") == 0,
      (c.v("nesTremMode"), c.v("nesTremShp")))
send(c, 18, tremolo={"depth": 100, "tremSync": 7, "mode": 2})
check("an older patch's MODE GATE X.X.XX.X: SHAPE 7, the same gate", c.v("nesTremMode") == 2)
p = gen_patches.migrate({"tremolo": {"mode": 1, "shape": 3}})
check("migrate: MODE 1 -> SHAPE 6 (PUMP)", p["tremolo"] == {"shape": 6}, p)

# ---------------------------------------------------------------- DRONE
send(c, 1)
c._raw_press("ctrl", ms=30); c._raw_tap("crsrdown", ms=40); c._raw_release("ctrl", ms=60)
check("CTRL + CRSR: DRONE; the glide slow (k 7)", c.v("playMode") == 2 and c.v("glideK") == 7, (c.v("playMode"), c.v("glideK")))
gbgl = [b for t, s, a, b in c.midi() if s & 0xF0 == 0xB0 and a == 5]
check("... the Game Boy's glide CC at its slowest (120)", gbgl and gbgl[-1] == 120, gbgl[-3:])
c.set("droneVc", 2)                                          # SUS4: 0 5 7 12 17
c._raw_tap("l", ms=40)                                       # latch
c.press("q", ms=200)
c.release("q", ms=4000)
held = c.v("heldList", 8)[:c.v("heldCount")]
check("C: the SUS4 drone C F G C F", held == [48, 53, 55, 60, 65], held)
c.press("t", ms=20)                                          # G
gate_off = 0
for _ in range(400):                                         # 6 s: the SID's gates never drop (glides, no new attacks)
    c.run_ms(15)
    gate_off += sum(1 for v in range(3) if not c.raw[0xD404 + 7 * v] & 1)
    if _ == 12:
        c.release("t", ms=0)
held = c.v("heldList", 8)[:c.v("heldCount")]
check("G: voice-led (each voice to the nearest G C D, above the root)", held == [55, 60, 62, 67, 72], held)
check("every SID voice glides there: its gate never drops", gate_off == 0, gate_off)
f = [sid_f(c, v) for v in range(3)]
c.run_ms(500)
check("... and the SID has arrived after a few seconds (steady)", f == [sid_f(c, v) for v in range(3)])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
