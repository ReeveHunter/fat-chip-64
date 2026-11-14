#!/usr/bin/env python3
"""Fat Chip 64 v0.30: the menu's tables under the KERNAL; ATTACK (BLIP,
CLICK), BEND IN, BEND OUT; REPEAT's PITCH SHIFT (semitones or scale steps) and
ECHOES (ALL CHIPS: SID 3 too); TREMOLO's PUMP, GATEs and tempo SYNC."""
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
    p["fx"].pop("detune", None)
    p["fx"].pop("warble", None)
    for k, v in fx.items():
        p["fx"][k] = v
    n0 = c.v("sxCount")
    c.midi_in(*gen_patches.sysex(p), ms=200)
    assert c.v("sxCount") == (n0 + 1) & 255, "SysEx not taken"


def note(c, n, on=True, ms=0):
    c.midi_in(0x90 if on else 0x80, n, 100 if on else 0, ms=ms)


c = C64(channels=None)
c.run_ms(400)
check("header V0.35", "V0.35" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- tables under the KERNAL
hs, hp, he = c.sym["hiStart"], c.sym["hiPhys"], c.sym["hiEnd"]
n = min(he - hs, 0xC000 - hp)                # (the load image above $C000: variables now)
check("the menu's high tables are copied to $E000 at start", hs == 0xE000 and
      c.raw[hs:hs + n] == c.raw[hp:hp + n], (hex(hs), hex(he)))
c.tap("return", ms=80)
rows = [c.screen_row(r) for r in range(25)]
check("the menu still opens with its pages", any("PLAYING" in r for r in rows), rows[:6])
c._raw_press("lshift", ms=8); c._raw_tap("return", ms=60); c._raw_release("lshift", ms=60)

# ---------------------------------------------------------------- ATTACK: BLIP
send(c, 2, attack={"blip": 1, "blipMs": 4})                   # OCTAVE for 40 ms
check("ATTACK on: sndBlip 1, 40 MS (10 steps)", c.v("sndBlip") == 1 and c.v("sndBlipT") == 10)
note(c, 48, ms=14)
f_blip = sid_f(c)
c.run_ms(200)
f_note = sid_f(c)
check("BLIP: an octave up at the start, then the note", abs(f_blip / f_note - 2) < 0.02, (f_blip, f_note))
note(c, 48, False, ms=300)

send(c, 2, attack={"blip": 3, "blipMs": 4})                   # 2 OCTAVES, then 1
note(c, 48, ms=14)
a = sid_f(c)
c.run_ms(40)
b = sid_f(c)
c.run_ms(200)
f = sid_f(c)
check("BLIP 2 OCTAVES: x4, then x2, then the note", abs(a / f - 4) < 0.05 and abs(b / f - 2) < 0.03, (a, b, f))
note(c, 48, False, ms=300)

# ---------------------------------------------------------------- ATTACK: CLICK
send(c, 2, attack={"blip": 0, "click": 1})
note(c, 48, ms=14)
w0 = c.raw[0xD404]
c.run_ms(100)
w1 = c.raw[0xD404]
check("CLICK: noise at the start, then the patch's waveform", w0 == 0x81 and w1 & 0xF0 == 0x40 and w1 & 1, (hex(w0), hex(w1)))
note(c, 48, False, ms=300)

# ---------------------------------------------------------------- BEND IN
t0 = c.cpu.processorCycles
send(c, 2, penv={"amount": -12, "time": 300})
cc = {a: b for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a in (80, 81)}
check("BEND IN: the Game Boy's pitch envelope CCs (80 below the middle, 81 a time)",
      80 in cc and cc[80] < 64 and cc.get(81, 0) > 0, cc)
note(c, 60, ms=14)
f0 = sid_f(c)
gl = max(c.v("nesGlH", 9))
c.run_ms(60)
fm = sid_f(c)
c.run_ms(900)
f1 = sid_f(c)
check("SID: starts an octave below (a scoop) and bends up to the note", f0 < fm < f1 and abs(f1 / f0 - 2) < 0.1, (f0, fm, f1))
check("NES: its glide starts 12 semitones away", gl == 12 or gl == 256 - 12, c.v("nesGlH", 9))
note(c, 60, False, ms=300)

send(c, 2, penv={"amount": 7, "time": 40})
note(c, 60, ms=14)
f0 = sid_f(c)
c.run_ms(400)
f1 = sid_f(c)
check("a drop: a fifth above, down to the note", abs(f0 / f1 - 1.498) < 0.05, (f0, f1))
note(c, 60, False, ms=300)

# ---------------------------------------------------------------- BEND OUT
send(c, 2, rdrop={"amount": 12, "time": 300}, env={"attack": 2, "decay": 6, "sustain": 15, "release": 1500})
note(c, 60, ms=200)
fh = sid_f(c)
note(c, 60, False, ms=40)
fa = sid_f(c)
c.run_ms(1000)
fb = sid_f(c)
check("BEND OUT: let go, the note sags (an octave over its time)", fh > fa > fb and abs(fh / fb - 2) < 0.1, (fh, fa, fb))
note(c, 60, ms=14)
check("... the next note starts on its pitch", abs(sid_f(c) / fh - 1) < 0.01, (sid_f(c), fh))
note(c, 60, False, ms=1600)

# ---------------------------------------------------------------- REPEAT: PITCH SHIFT, ECHOES


def echoes(c, t0):
    return [a for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0x90 and b and b < 100]


send(c, 17, repeat={"time": 9, "repeats": 4, "level": 90, "shift": 12})
t0 = c.cpu.processorCycles
note(c, 48, ms=60)
note(c, 48, False, ms=1500)
e = echoes(c, t0)
check("SHIFT +12 SEMIS: each echo an octave up from the last, stops above the top", e[:3] == [60, 72, 84], e)
send(c, 17, repeat={"time": 9, "repeats": 4, "level": 90, "shift": -1, "shiftIn": 1})
t0 = c.cpu.processorCycles
note(c, 60, ms=60)
note(c, 60, False, ms=1500)
e = echoes(c, t0)
check("SHIFT -1 SCALE STEPS (C major): B A G F", e[:4] == [59, 57, 55, 53], e)
send(c, 17, repeat={"time": 9, "repeats": 4, "level": 90, "hop": 1})
note(c, 48, ms=100)
check("ECHOES ALL CHIPS: SID 3 joins the echo voices", c.v("vEcho", 9)[6] == 1 and c.v("rpNEcho") == 3,
      (c.v("vEcho", 9), c.v("rpNEcho")))
note(c, 48, False, ms=1500)
send(c, 17, repeat={"time": 9, "repeats": 4, "level": 90, "hop": 2})
note(c, 48, ms=100)
check("ECHOES ONE CHIP: one echo voice", c.v("rpNEcho") == 1, c.v("rpNEcho"))
note(c, 48, False, ms=1500)

# ---------------------------------------------------------------- TREMOLO: SYNC, PUMP, GATE
send(c, 18, tremolo={"depth": 100, "tremSync": 3, "mode": 1})    # 1/4, PUMP
bm = c.raw[c.sym["beatMs"]] | c.raw[c.sym["beatMs"] + 1] << 8
ts = c.v("tremSyncL") | c.v("tremSyncH") << 8
check("SYNC 1/4: the phase step from the tempo (655360 / beat ms)", abs(ts - 655360 // bm) <= 1, (ts, bm))
check("... PUMP mode", c.v("tremMode") == 1 or c.v("nesTremMode") == 1, c.v("nesTremMode"))
note(c, 60, ms=100)
vols = []
for _ in range(60):
    c.run_ms(10)
    vols.append(c.v("tremA"))
check("PUMP: the drop is deepest at the beat and eases off (a saw), once a beat",
      max(vols) >= 12 and min(vols) <= 2 and sum(1 for a, b in zip(vols, vols[1:]) if b > a + 6) in (1, 2), vols)
note(c, 60, False, ms=500)
send(c, 18, tremolo={"depth": 100, "tremSync": 7, "mode": 2})    # 1/16, GATE X.X.XX.X
note(c, 60, ms=100)
vols = []
for _ in range(100):
    c.run_ms(10)
    vols.append(c.v("tremA"))
check("GATE: all or nothing (the NES chopped on and off)", set(vols) == {0, 15}, vols)
note(c, 60, False, ms=500)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
