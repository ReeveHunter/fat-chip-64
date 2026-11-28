#!/usr/bin/env python3
"""Fat Chip 64 v0.69: THE LOOPER (sampler stage 2) - six tracks of pad hits on
one clock: F5 arm / set the length / overdub / play, smart lengths in whole
bars, undo, mute, stop, cue, quantize, RUN/STOP + Q-Y on the play screen, a
beat waiting for the loops' bar. Also: built-in patches stored as differences
(PatchUnpack) and the MidiNES's bend factor from the SID's tables."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0
CPS = 985248 / 1000                                  # cycles a ms


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def mod(c, m, *keys, ms=40):
    c._raw_press(m, ms=30)
    for k in keys:
        c._raw_tap(k, ms=ms)
    c._raw_release(m, ms=60)


def hits(c, t0, t1=None):
    """MidiNES sample note-ons after cycle t0: (ms after t0, note)."""
    return [((t - t0) / CPS, a) for t, s, a, b in c.midi() if t >= t0 and (t1 is None or t < t1) and s == 0x94 and b]


def tap(c, key, ms):
    c._raw_press(key, ms=20)
    c._raw_release(key, ms=max(ms - 20, 1))


def st(c):
    return c.v("trkSt", 6)


c = C64(channels=None)
c.fkeys_036 = False
c.keys_039 = False
c.run_ms(400)
check("header V0.69", "V0.69" in c.screen_row(0), c.screen_row(0))
bpm = c.v("bpm")
BAR = 4 * 60000 / bpm
kit = c.v("kitBuf", 12)
K, S, H = kit[1] & 0x7F, kit[4] & 0x7F, 12          # Z, X and C's samples
mod(c, "runstop", "return", ms=60)
c.run_ms(200)
check("the sampler: six empty tracks on screen", c.v("smpOn") == 1 and "-----" in c.screen_row(16) and "-----" in c.screen_row(21),
      [c.screen_row(r) for r in (16, 21)])

# ---------------------------------------------------------------- a 1-bar take
c._raw_tap("f5", ms=60)
check("F5: track 1 armed", st(c)[0] == 1 and "ARMED" in c.screen_row(16), c.screen_row(16))
t0 = c.cpu.processorCycles
for k in ("z", "x", "z", "x"):
    tap(c, k, BAR / 4)
check("the first hit: recording", st(c)[0] == 2, st(c))
c.run_ms(40)
c._raw_tap("f5", ms=40)                              # a little after the bar: 1 bar
check("F5 just after the bar: one bar long, playing", st(c)[0] == 3 and c.v("trkLenL") == 96 and c.v("trkLenH") == 0
      and c.v("trkCnt") == 4, (st(c), c.v("trkLenL"), c.v("trkCnt")))
t1 = c.cpu.processorCycles
c.run_ms(BAR * 2 + 100)
h = hits(c, t1)
notes = [n for _, n in h]
check("it plays it back: kick and snare taking turns (F5 came just after its first kick)",
      len(notes) >= 8 and all(notes[i] != notes[i + 1] for i in range(7)) and set(notes[:8]) == {K, S}, h[:8])
gaps = [round(h[i + 1][0] - h[i][0]) for i in range(7)]
check("... a quarter note apart (within a tick)", all(abs(g - BAR / 4) < BAR / 96 + 3 for g in gaps), gaps)
check("the screen: 1 BARS, PLAY", "PLAY" in c.screen_row(16) and " 1 BARS" in c.screen_row(16), c.screen_row(16))

# ---------------------------------------------------------------- overdub, undo
c._raw_tap("f5", ms=30)
check("F5: overdub", st(c)[0] == 4)
for _ in range(4):
    c.run_ms(BAR / 8)
    tap(c, "c", BAR / 8)
c._raw_tap("f5", ms=30)
check("F5: playing again, the pass kept (8 hits)", st(c)[0] == 3 and c.v("trkCnt") == 8 and c.v("trkUndo") == 1,
      (st(c), c.v("trkCnt"), c.v("trkUndo")))
t1 = c.cpu.processorCycles
c.run_ms(BAR + 50)
check("... the hats play with it", sum(1 for _, n in hits(c, t1) if n == H) >= 4, hits(c, t1))
c._raw_tap("left", ms=60)
t1 = c.cpu.processorCycles
c.run_ms(BAR + 50)
check("<-: the overdub undone (no hats), UNDONE on screen", not any(n == H for _, n in hits(c, t1)) and "UNDONE" in c.screen_row(16),
      (hits(c, t1), c.screen_row(16)))
c._raw_tap("left", ms=60)
t1 = c.cpu.processorCycles
c.run_ms(BAR + 50)
check("<- again: back", sum(1 for _, n in hits(c, t1) if n == H) >= 4)

# ---------------------------------------------------------------- mute, stop, cue
mod(c, "cbm", "1")
t1 = c.cpu.processorCycles
c.run_ms(BAR)
check("C= + 1: muted (nothing), MUTE on screen", hits(c, t1) == [] and "MUTE" in c.screen_row(16), c.screen_row(16))
mod(c, "cbm", "1")
c._raw_tap("f7", ms=60)
t1 = c.cpu.processorCycles
c.run_ms(BAR)
check("F7: stopped", st(c)[0] == 5 and hits(c, t1) == [], st(c))
c._raw_tap("f5", ms=20)
check("F5 on a stopped track: cued", st(c)[0] == 6)
c.run_ms(BAR + 50)
check("... and playing from the next bar line", st(c)[0] == 3 and c.v("lpPh") < 40 + 96 and len(hits(c, t1)) > 0, (st(c), c.v("lpPh")))

# ---------------------------------------------------------------- a 2-bar take (late and early)
c._raw_tap("f3", ms=40)
check("F3: track 2", c.v("lpSel") == 1 and c.screen_row(17).startswith(">2"), c.screen_row(17))
c._raw_tap("f5", ms=40)
c.run_ms(20)
while c.v("lpPh") > 10:
    c.run_ms(5)
tap(c, "x", BAR * 1.75)                             # (the first hit near a bar line)
c._raw_tap("f5", ms=40)                              # 1.75 bars: rounds to 2
check("F5 at 1.75 bars: 2 bars long", c.v("trkLenL", 6)[1] == 192 and st(c)[1] == 3, (c.v("trkLenL", 6), st(c)))
check("... and it runs on to its end (it's in its second bar)", 96 * 1.5 < c.v("trkPosL", 6)[1] <= 192, c.v("trkPosL", 6))

# ---------------------------------------------------------------- quantize
c.set("lpQnt", 1)                                     # 1/16
c._raw_tap("f3", ms=40)
c._raw_tap("f5", ms=40)
while c.v("lpPh") != 10:
    c.run_ms(2)
tap(c, "z", BAR / 8)                                  # tick ~10: 12 on a 16th grid
c.run_ms(BAR / 4)
tap(c, "z", BAR / 8)
c._raw_tap("f5", ms=40)
P = c.sym["lpBaseLo"]
base = c.raw[P + 2] | c.raw[c.sym["lpBaseHi"] + 2] << 8
U = lambda a: c.under[a - 0xD000]                   # (the RAM under the I/O)
ticks = [U(base + 3 * i) | (U(base + 3 * i + 1) & 7) << 8 for i in range(c.v("trkCnt", 6)[2])]
check("QUANTIZE 1/16: hits on the grid (multiples of 6 ticks)", ticks and all(t % 6 == 0 for t in ticks), ticks)
c.set("lpQnt", 0)
c._raw_tap("f7", ms=30)
c._raw_tap("f7", ms=30)
check("F7, F7: track 3 stopped, then cleared", st(c)[2] == 0 and c.v("trkCnt", 6)[2] == 0, (st(c), c.v("trkCnt", 6)))

# ---------------------------------------------------------------- the play screen
mod(c, "runstop", "return", ms=60)
c.run_ms(200)
check("out of the sampler: the loops still play", c.v("smpOn") == 0 and st(c)[0] == 3)
t1 = c.cpu.processorCycles
c._raw_press("runstop", ms=30); c._raw_tap("w", ms=40); c._raw_release("runstop", ms=100)
check("RUN/STOP + W: track 2 overdubs, the beat didn't start", st(c)[1] == 4 and c.v("beatRun") == 0, (st(c), c.v("beatRun")))
c.run_ms(300)                                        # (not a double with the last)
c._raw_press("runstop", ms=30); c._raw_tap("w", ms=40); c._raw_tap("w", ms=40); c._raw_release("runstop", ms=100)
check("RUN/STOP + W twice quickly: stopped", st(c)[1] == 5, st(c))

# ---------------------------------------------------------------- a beat waits for the loops' bar
while c.v("lpPh") != 30:
    c.run_ms(2)
mod(c, "runstop", ms=10)
check("RUN/STOP tapped with loops going: the beat waits", c.v("beatRun") == 0 and c.v("lpBeatCue") == 1)
while c.v("beatRun") == 0:
    c.run_ms(2)
check("... and starts on their bar line", c.v("lpPh") < 6, c.v("lpPh"))
c.run_ms(BAR * 2)
check("the loop keeps time with the beat (its step 0 at the loops' bar)", c.v("lpRel") <= 6 and st(c)[0] == 3)
mod(c, "runstop", ms=10)
c.run_ms(200)

t1 = c.cpu.processorCycles
c.midi_in(*([0xF8] * 60), ms=BAR / 2)                  # (a burst in while the loops play)
check("MIDI in while the loops play: no byte lost (the hits under the I/O a moment at a time)", c.rx_overrun == 0, c.rx_overrun)

# ---------------------------------------------------------------- patches, bends
size = c.sym["patchName"] - c.sym["livePatch"] + 17
check("PatchUnpack: the live patch is the built-in one, whole", c.v("livePatch", size) == c.builtin_patch(c.v("soundMode"), size)
      or c.v("soundMode") >= 25)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
