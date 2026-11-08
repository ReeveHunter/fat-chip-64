#!/usr/bin/env python3
"""Fat Chip 64 v0.13: the menu (SHIFT+RETURN), keytar sync (clock, Start /
Stop, rhythm and voice buttons), the wheel, the three keytar buttons,
Synthcart tempos, latch style, Fat Bass lock, ; faster / : slower."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

fails = 0
GB = (10, 11, 12)
DMC, NOISE = 4, 3


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def since(c, t0):
    return [(t, s, a, b) for t, s, a, b in c.midi(since=t0)]


def clocks(c, bpm, beats, jitter_ms=0.0, start=False, seed=5):
    """Queue MIDI clocks (24 a beat) from now, optionally a Start first;
    returns the cycle of each beat clock (every 24th, the first included)."""
    rnd = random.Random(seed)
    per = 60000 / bpm / 24 * CYCLES_PER_MS
    t = max(c.cpu.processorCycles, c.rx_last) + 100
    beat_at = []
    if start:
        c.rx_q.append((t, 0xFA))
        t += 400
    for i in range(int(beats * 24)):
        j = 0 if i == 0 else rnd.uniform(-jitter_ms, jitter_ms)    # (a Start comes before its clock)
        tt = int(t + i * per + j * CYCLES_PER_MS)
        c.rx_q.append((tt, 0xF8))
        if i % 24 == 0:
            beat_at.append(tt)
    c.rx_q.sort()
    c.rx_last = c.rx_q[-1][0]
    return beat_at


def sid_freq(c, v):
    return c.sid(v)[0]


c = C64(channels=None)
c.run_ms(400)

# ---------------------------------------------------------------- menu
c.press("lshift", ms=10)
c.tap("return", ms=40)
c.release("lshift", ms=40)
check("SHIFT+RETURN: the menu", c.v("menuOn") == 1 and "MENU" in c.screen_row(0), c.screen_row(0))
rows = [c.screen_row(r) for r in range(25)]
check("menu: SOUND, PLAYING, then DEVICE SYNC at the bottom",
      rows[2].startswith("SOUND") and rows[5].startswith("PLAYING") and rows[10].startswith("DEVICE SYNC"), rows[10])
check("menu: defaults", "AS SOUND" in rows[3] and "SMART" in rows[6] and "BEND DOWN" in rows[7] and "2 SEMITONES" in rows[8]
      and "KEYTAR" in rows[11] and "KEYTAR" in rows[12] and "PICK BEAT" in rows[13] and "IGNORE" in rows[14]
      and "PICK SOUND" in rows[15] and "BEND" in rows[16] and "VIBRATO" in rows[17] and "GLIDE" in rows[18]
      and "SUSTAIN" in rows[19], [rows[r][23:] for r in (3, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19)])
check("menu: the cursor on FAT BASS", rows[3].startswith(">"), rows[3])
c.tap("return", ms=40)
check("RETURN: FAT BASS ALWAYS", c.v("fbLock") == 1 and "ALWAYS" in c.screen_row(3), c.screen_row(3))
c.tap("return", ms=40)
check("RETURN again: NEVER (and Fat Bass off in FAT)", c.v("fbLock") == 2 and c.v("fatBass") == 0, c.screen_row(3))
c.press("lshift", ms=10); c.tap("crsrright", ms=40); c.tap("crsrright", ms=40); c.release("lshift", ms=10)
check("SHIFT+CRSR RIGHT twice: back to AS SOUND", c.v("fbLock") == 0 and c.v("fatBass") == 1, c.screen_row(3))
c.tap("crsrdown", ms=40)
check("CRSR DOWN: LATCH STYLE", c.screen_row(6).startswith(">") and not c.screen_row(3).startswith(">"))
c.tap("crsrright", ms=40)
check("CRSR RIGHT: HOLD", c.v("latchStyle") == 1 and "HOLD" in c.screen_row(6), c.screen_row(6))
c.tap("=", ms=40)
check("= in the menu turns latch on as HOLD", c.v("latch") == 2)
c.tap("=", ms=40)
c.press("lshift", ms=10); c.tap("crsrdown", ms=40); c.tap("crsrdown", ms=40); c.release("lshift", ms=10)
check("SHIFT+CRSR DOWN twice: up, wraps to SUSTAIN BUTTON", c.screen_row(19).startswith(">"), c.screen_row(19))
t0 = c.cpu.processorCycles
c.press("q", ms=100)
check("notes play while the menu is up", 60 - 12 in [a for _, s, a, b in since(c, t0) if (s & 0xF0) == 0x90 and b])
c.release("q", ms=100)
c.press("lshift", ms=10)
c.tap("return", ms=40)
c.release("lshift", ms=250)
check("SHIFT+RETURN: back to play, the screen redrawn", c.v("menuOn") == 0 and "FAT CHIP 64" in c.screen_row(0)
      and c.screen_row(1).startswith("V FAT") and "MIDI OUT" in c.screen_row(23), (c.screen_row(0), c.screen_row(1)))

# ---------------------------------------------------------------- keytar clock: tempo
c.run_ms(100)
t0 = c.cpu.processorCycles
clocks(c, 110, 6)
c.run_ms(1800)
c.tap("b", ms=150); c.tap("b", ms=150); c.tap("b", ms=150)
check("taps do nothing while the keytar sets the tempo", c.v("bpm") == 110, c.v("bpm"))
c.run_ms(1000)
check("keytar clock at 110 BPM: Fat Chip follows (545 ms)", c.v("bpm") == 110 and abs((c.v("beatMs", 2)[0] | c.v("beatMs", 2)[1] << 8) - 545) <= 1,
      (c.v("bpm"), c.v("beatMs", 2)))
tempo = [(a, b) for _, s, a, b in since(c, t0) if s == 0xBA and a in (107, 108)]
check("... and tells the Game Boy (CC 107/108 = 110 x 32)", tempo[-2:] == [(107, 27), (108, 64)], tempo[-4:])
clocks(c, 107, 8, jitter_ms=4, seed=2)
c.run_ms(4600)
check("107 BPM with +-4 ms clock jitter: 107 (averaged)", abs(c.v("bpm") - 107) <= 1, c.v("bpm"))
c.run_ms(500)
c.tap("b", ms=200); c.tap("b", ms=200); c.tap("b", ms=200); c.tap("b", ms=50)
check("clock stopped: taps set the tempo again (150)", abs(c.v("bpm") - 150) <= 2, c.v("bpm"))

# ---------------------------------------------------------------- keytar start / stop, beats in step
c.set("syncDrums", 0)
clocks(c, 100, 2.5)                          # (the keytar's clock runs even while stopped)
c.run_ms(1400)
beats = clocks(c, 100, 8, start=True, seed=7)
t0 = c.cpu.processorCycles
c.run_ms(5000)
msgs = since(c, t0)
hits = [t for t, s, a, b in msgs if (s in (0x93, 0x94)) and b]
check("keytar Start: the beat demo plays", c.v("beatRun") == 1 and len(hits) > 20, len(hits))
first = hits[0]
check("step 1 follows the first beat clock (within 12 ms: it waits for it)", 0 <= (first - beats[0]) / CYCLES_PER_MS <= 12,
      round((first - beats[0]) / CYCLES_PER_MS, 1))
# every later hit on the keytar's 16th grid (its beat / 4), allowing the
# MidiNES queue's few ms (a kick and a hat on one step go out one after another)
grid = []
for bt in beats:
    for k in range(4):
        grid.append(bt + k * (60000 / 100 / 4) * CYCLES_PER_MS)
err = [min((h - g) / CYCLES_PER_MS for g in grid if g <= h + 2 * CYCLES_PER_MS) for h in hits[3:] if h < beats[-1]]
check("later hits sit on the keytar's 16th grid: 0-11 ms after it, 5 on average (predicted, not waiting)",
      err and min(err) >= -2 and max(err) <= 11 and sum(err) / len(err) <= 5, (round(min(err), 1), round(max(err), 1), [round(x, 1) for x in err[:12]]))
check("tempo from the clock: 100", c.v("bpm") == 100, c.v("bpm"))
t0 = c.cpu.processorCycles
c.midi_in(0xFC, ms=200)
check("keytar Stop: the beat stops", c.v("beatRun") == 0)

# ---------------------------------------------------------------- rhythm / voice buttons
c.midi_in(0xCF, 13, ms=200)                 # Hard Rock
check("rhythm button (Hard Rock, PC 13 on ch 16): ROCK", c.v("beatSel") == 4 and "ROCK" in c.screen_row(23), c.screen_row(23))
c.midi_in(0xCF, 9, ms=200)                  # Jazz Waltz
check("Jazz Waltz: 6/8", c.v("beatSel") == 5)
c.midi_in(0xC0, 4, ms=300)                  # voice button 4 on the key channel
check("voice button (PC 4 on ch 1): WHISTLE", c.v("soundMode") == 4 and "WHISTLE" in c.screen_row(1), c.screen_row(1))
c.midi_in(0xC0, 0, ms=300)
check("voice button 0: FAT", c.v("soundMode") == 0)

# ---------------------------------------------------------------- wheel
c.midi_in(0x90, 60, 64, ms=150)
f0 = sid_freq(c, 0)
t0 = c.cpu.processorCycles
c.midi_in(0xE0, 127, 127, ms=150)
f1 = sid_freq(c, 0)
gbb = [((b << 7) | a) for _, s, a, b in since(c, t0) if s == 0xEA]
nesb = [((b << 7) | a) for _, s, a, b in since(c, t0) if s == 0xE0]
check("wheel up: SID up 2 semitones", abs(f1 / f0 - 2 ** (2 / 12)) < 0.01, round(f1 / f0, 4))
check("wheel up: Game Boy bend 8192 + 2/12 (its range is 12)", gbb and gbb[-1] == 8192 + 1366, gbb[-1:])
check("wheel up: NES pulse bend above centre", nesb and nesb[-1] > 8192, nesb[-1:])
c.midi_in(0xE0, 0, 0, ms=150)
f2 = sid_freq(c, 0)
check("wheel down: SID down 2 semitones", abs(f2 / f0 - 2 ** (-2 / 12)) < 0.01, round(f2 / f0, 4))
t0 = c.cpu.processorCycles
c.midi_in(0xE0, 0, 64, ms=150)
gbb = [((b << 7) | a) for _, s, a, b in since(c, t0) if s == 0xEA]
check("wheel centred: everything back", sid_freq(c, 0) == f0 and gbb[-1:] == [8192], (sid_freq(c, 0), f0, gbb[-1:]))

# ---------------------------------------------------------------- buttons
t0 = c.cpu.processorCycles
c.midi_in(0xB0, 1, 127, ms=10)              # vibrato button held
f = []
for _ in range(30):
    c.run_ms(10)
    f.append(sid_freq(c, 0))
lfo = [(a, b) for _, s, a, b in since(c, t0) if s == 0xBA and a in (78, 1)]
check("VIBRATO button: SID vibrato in FAT (which has none)", len(set(f)) >= 5, sorted(set(f))[:3])
check("VIBRATO button: Game Boy LFO to pitch with depth", (78, 0) in lfo and (1, 24) in lfo, lfo)
t0 = c.cpu.processorCycles
c.midi_in(0xB0, 1, 0, ms=100)
check("let go: no vibrato, Game Boy LFO depth back to 0", sid_freq(c, 0) == f0 and
      (1, 0) in [(a, b) for _, s, a, b in since(c, t0) if s == 0xBA], sid_freq(c, 0))
c.midi_in(0x90, 60, 0, ms=200)
# glide
c.midi_in(0xB0, 65, 127, ms=10)
c.midi_in(0x90, 60, 64, ms=150)
fa = sid_freq(c, 0)
c.midi_in(0x80, 60, 0, 0x90, 67, 64, ms=8)
path = []
for _ in range(10):
    c.run_ms(15)
    path.append(sid_freq(c, 0))
check("PORTAMENTO button: the SID glides", len(set(path)) >= 4 and path[0] < path[-1], (fa, path))
c.midi_in(0x80, 67, 0, 0xB0, 65, 0, ms=200)
# sustain
c.midi_in(0xB0, 64, 127, ms=10)
c.midi_in(0x90, 64, 64, ms=120)
c.midi_in(0x80, 64, 0, ms=200)
check("SUSTAIN button: a released note keeps sounding", c.v("heldCount") >= 1, c.v("heldCount"))
c.midi_in(0xB0, 64, 0, ms=200)
check("SUSTAIN let go: it stops", c.v("heldCount") == 0, c.v("heldCount"))
# a button with another task
c.set("btnTask", 0)                          # VIBRATO button -> MUTE (action 0)
c.midi_in(0x90, 60, 64, ms=150)
c.midi_in(0xB0, 1, 127, ms=60)
check("VIBRATO button set to MUTE: mutes while held", c.v("moment") == 1)
c.midi_in(0xB0, 1, 0, ms=60)
check("... and lets go", c.v("moment") == 0)
c.set("btnTask", 3)                          # back to VIBRATO
c.midi_in(0x80, 60, 0, ms=200)

# ---------------------------------------------------------------- Synthcart
c.set("syncTempo", 2)
for _ in range(4):
    c.tap("b", ms=165)                       # 330 ms: about 182 BPM
c.run_ms(50)
b16 = c.v("beat16L") | c.v("beat16H") << 8
check("SYNTHCART: taps snap to 20 Atari frames (179.77 BPM; 5334 / 16 ticks)", b16 == 5334, (b16, c.v("bpm")))
c.set("syncTempo", 1)

# ---------------------------------------------------------------- arp keys
c.tap("a", ms=40)
c.tap(";", ms=40)
c.tap(";", ms=40)
c.run_ms(150)
check("; is faster (FREE 30 -> 25 -> 20 ms)", "20MS" in c.screen_row(19).replace(" ", ""), c.screen_row(19))

# ---------------------------------------------------------------- SPACE actions, bend range, bass display
c.tap("a", ms=30); c.tap("a", ms=60)        # arp off (UNISON -> SPARKLE -> OFF)
check("arp off again", c.v("arpMode") == 0)
c.run_ms(150)
check("SPACE: BEND DOWN by default", c.v("spaceAct") == 1 and "BEND DN" in c.screen_row(22), c.screen_row(22))
t0 = c.cpu.processorCycles
c.run_ms(10)
rng = [x[1:] for x in c.midi() if x[2] == 85 and (x[1] & 15) in GB]
check("Game Boy bend range 12 (CC 85 = 62) on its three channels", sorted(set(x[0] & 15 for x in rng)) == [10, 11, 12]
      and all(x[2] == 62 for x in rng), rng[:3])
c.press("o", ms=300)                         # D4 (62)
check("voice table: Fat Bass voices show the note they play (D 2)", c.screen_row(17)[16:19] == "D 2"
      and c.screen_row(18)[16:19] == "D 2" and c.screen_row(10)[16:19] == "D 4", (c.screen_row(17), c.screen_row(10)))
f0 = sid_freq(c, 0)

c.set("spaceAct", 2)                         # BEND UP
c.press("space", ms=1200)
check("BEND UP: SID up 2 semitones", abs(sid_freq(c, 0) / f0 - 2 ** (2 / 12)) < 0.004, round(sid_freq(c, 0) / f0, 4))
c.release("space", ms=700)
check("BEND UP let go: back", sid_freq(c, 0) == f0)

c.set("bendRange", 11)                       # 12 semitones
c.midi_in(0xE0, 0, 0, ms=150)                # wheel all the way down
check("BEND RANGE 12: wheel down = an octave down", abs(sid_freq(c, 0) / f0 - 0.5) < 0.004, round(sid_freq(c, 0) / f0, 4))
gbb = [((b << 7) | a) for t, s, a, b in c.midi() if (s & 0xF0) == 0xE0 and (s & 15) == 10]
check("... the Game Boy bottoms out (range 12)", gbb and gbb[-1] <= 4, gbb[-1:])
c.midi_in(0xE0, 0, 64, ms=150)
check("wheel centred", sid_freq(c, 0) == f0)
c.set("bendRange", 1)

c.set("spaceAct", 7)                         # VINYL STOP
c.press("space", ms=1200)
check("VINYL STOP: pitch an octave down", abs(sid_freq(c, 0) / f0 - 0.5) < 0.004 and c.v("vinylLvl") == 255,
      round(sid_freq(c, 0) / f0, 4))
c.release("space", ms=700)
check("VINYL STOP let go: winds back up", sid_freq(c, 0) == f0 and c.v("vinylLvl") == 0)

c.set("spaceAct", 3)                         # VIBRATO
c.press("space", ms=100)
f = set()
for _ in range(20):
    c.run_ms(15)
    f.add(sid_freq(c, 0))
check("SPACE VIBRATO: SID vibrato while held", len(f) >= 5, len(f))
c.release("space", ms=100)
check("... gone when let go", sid_freq(c, 0) == f0)

c.set("spaceAct", 4)                         # TREMOLO
t0 = c.cpu.processorCycles
c.press("space", ms=50)
vols = set()
for _ in range(30):
    c.run_ms(10)
    vols.add(c.raw[0xD418] & 15)
cc7 = [b for t, s, a, b in since(c, t0) if s in (0xB0, 0xB1) and a == 7]
check("TREMOLO in FAT: SID volume moves", len(vols) >= 4, sorted(vols))
check("TREMOLO in FAT: NES pulse levels move (CC7)", len(set(cc7)) >= 3, cc7[:8])
c.release("space", ms=60)
cc7 = [b for t, s, a, b in since(c, t0) if s in (0xB0, 0xB1) and a == 7]
check("TREMOLO let go: SID volume 15, NES back to 127", c.raw[0xD418] & 15 == 15 and cc7[-2:] == [127, 127], cc7[-2:])

c.set("spaceAct", 5)                         # ARP
c.press("space", ms=200)
check("ARP held: the arp runs (in the last mode A chose: SPARKLE)", c.v("arpMode") == 2 and c.v("arpRunning") == 1, c.v("arpMode"))
c.release("space", ms=60)
check("ARP let go: off again", c.v("arpMode") == 0)

c.set("spaceAct", 6)                         # STUTTER
c.set("syncTempo", 1)
t0 = c.cpu.processorCycles
c.press("space", ms=10)
cut = []
for _ in range(400):
    c.run_ms(5)
    cut.append(c.v("stutCut"))
changes = sum(1 for a, b in zip(cut, cut[1:]) if a != b)
offs = [x for x in since(c, t0) if x[1] == 0x8A]
check("STUTTER: the chord cuts in and out (2 s)", changes >= 4 and offs, (changes, len(offs)))
check("STUTTER: no red border (not a mute you set)", c.raw[0xD020] & 15 == 0)
c.release("space", ms=100)
check("STUTTER let go: sounding again", c.v("stutCut") == 0 and c.v("muteNow") == 0)
c.release("o", ms=100)
c.set("spaceAct", 1)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
