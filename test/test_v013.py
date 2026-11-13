#!/usr/bin/env python3
"""Fat Chip 64 v0.13: the menu (SHIFT+RETURN), keytar sync (clock, Start /
Stop, rhythm and voice buttons), the wheel, the three keytar buttons,
Synthcart tempos, latch style, Fat Bass lock, ; faster / : slower."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

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
    t = max(c.cpu.processorCycles, c.rx_last) + 400       # (MIDI bytes are 320 us apart at least)
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

# ---------------------------------------------------------------- menu (v0.24's: test_v024.py has more)
c.tap("return", ms=60)
check("RETURN: the menu", c.v("menuOn") == 1 and "MENU" in c.screen_row(0), c.screen_row(0))
rows = [c.screen_row(r) for r in range(25)]
check("menu: HELP, the chips, PATCH, PLAYING, DEVICES, the SHS-10 (in use)",
      rows[2].startswith("> HELP") and rows[4][2:].startswith("SID") and rows[5][2:].startswith("GAME BOY")
      and rows[6][2:].startswith("MIDINES") and rows[8][2:].startswith("PATCH") and rows[9][2:].startswith("PLAYING")
      and rows[10][2:].startswith("ONE KEY PLAY") and rows[11][2:].startswith("DEVICES") and rows[13][2:].startswith("YAMAHA SHS-10")
      and rows[14].strip() == "", rows[2:15])
for _ in range(5):
    c.tap("crsrdown", ms=40)
check("CRSR DOWN x5 (past the gaps): PLAYING", c.screen_row(9).startswith("> PLAYING"), c.screen_row(9))
c.tap("return", ms=60)
rows = [c.screen_row(r) for r in range(25)]
check("PLAYING: its page and defaults", "PLAYING" in rows[0] and rows[2].startswith("> LATCH STYLE") and "SMART" in rows[2]
      and "BEND DOWN" in rows[3] and "2 SEMITONES" in rows[4] and "DEFAULT" in rows[5], rows[2:6])
c.tap("crsrright", ms=40)
check("CRSR RIGHT: HOLD", c.v("latchStyle") == 1 and "HOLD" in c.screen_row(2), c.screen_row(2))
c.tap("=", ms=40)
check("L in the menu turns latch on as HOLD", c.v("latch") == 2)
c.tap("=", ms=40)
t0 = c.cpu.processorCycles
c.press("q", ms=100)
check("notes play while the menu is up", 60 - 12 in [a for _, s, a, b in since(c, t0) if (s & 0xF0) == 0x90 and b])
c.release("q", ms=100)
c.press("lshift", ms=10); c.tap("return", ms=60); c.release("lshift", ms=40)
check("SHIFT+RETURN: back to the main page, on PLAYING", c.v("menuPage") == 0 and c.screen_row(9).startswith("> PLAYING"),
      c.screen_row(9))
c.press("lshift", ms=10); c.tap("return", ms=60); c.release("lshift", ms=250)
check("SHIFT+RETURN again: back to play, the screen redrawn", c.v("menuOn") == 0 and "FAT CHIP 64" in c.screen_row(0)
      and c.screen_row(2).startswith("FAT   1 FAT") and c.screen_row(24).startswith("F1/F3"), (c.screen_row(0), c.screen_row(2)))
c.set("latchStyle", 0)

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
check("rhythm button (Hard Rock, PC 13 on ch 16): ROCK", c.v("beatSel") == 4 and "ROCK" in c.screen_row(12), c.screen_row(12))
c.midi_in(0xCF, 9, ms=200)                  # Jazz Waltz
check("Jazz Waltz: 6/8", c.v("beatSel") == 5)
c.midi_in(0xC0, 4, ms=300)                  # voice button 4 on the key channel
check("voice button (PC 4 on ch 1): WHISTLE", c.v("soundMode") == 4 and "WHISTLE" in c.screen_row(2), c.screen_row(2))
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
check("wheel up: Game Boy bend 8192 + 2/24 (its range is 24, v0.17)", gbb and gbb[-1] == 8192 + 682, gbb[-1:])
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
check("; is faster (FREE 30 -> 25 -> 20 ms)", "20MS" in c.screen_row(10).replace(" ", ""), c.screen_row(10))

# ---------------------------------------------------------------- SPACE actions, bend range, bass display
c.tap("a", ms=30); c.tap("a", ms=60)        # arp off (UNISON -> SPARKLE -> OFF)
check("arp off again", c.v("arpMode") == 0)
c.run_ms(150)
check("SPACE: BEND DOWN by default", c.v("spaceAct") == 1 and "BEND DN" in c.screen_row(13), c.screen_row(13))
t0 = c.cpu.processorCycles
c.run_ms(10)
rng = [x[1:] for x in c.midi() if x[2] == 85 and (x[1] & 15) in GB]
check("Game Boy bend range 24 (CC 85 = 127) on its three channels", sorted(set(x[0] & 15 for x in rng)) == [10, 11, 12]
      and all(x[2] == 127 for x in rng), rng[:3])
c.press("o", ms=500)                         # D4 (62)
check("chip lines: Fat Bass voices show the note they play (D 2)", c.screen_row(5)[28:31] == "D 2"
      and c.screen_row(6)[28:31] == "D 2" and c.screen_row(4)[16:19] == "D 4", (c.screen_row(4), c.screen_row(5), c.screen_row(6)))
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
check("... the Game Boy an octave down too (half its range 24)", gbb and abs(gbb[-1] - 4096) <= 4, gbb[-1:])
c.midi_in(0xE0, 0, 64, ms=150)
check("wheel centred", sid_freq(c, 0) == f0)
c.set("bendRange", 1)

c.set("spaceAct", 7)                         # VINYL STOP
c.press("space", ms=1200)
check("VINYL STOP: stopped, the SID two octaves down (v0.15)", abs(sid_freq(c, 0) / f0 - 0.25) < 0.004 and c.v("vinylLvl") == 255,
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
check("TREMOLO let go: SID volume 15, NES back to its envelope's sustain (FAT: 12, CC7 96)",
      c.raw[0xD418] & 15 == 15 and cc7[-2:] == [96, 96], cc7[-2:])

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

# ---------------------------------------------------------------- REPEAT
def sound_to(name):
    for _ in range(25):
        if c.screen_row(2)[8:24].rstrip() == name:
            return True
        c.tap("v", ms=250)
    return False


c.set("syncTempo", 1)
check("ECHO PLUCK", sound_to("ECHO PLUCK"), c.screen_row(2))
check("ECHO PLUCK: REPEAT on, 1/8 dotted, 5 repeats, 70 %", c.v("repeatOn") == 1 and c.v("rpTime") == 1
      and c.v("rpCount") == 4 and c.v("rpLevel") == 3)
beat = c.v("beatMs", 2)[0] | c.v("beatMs", 2)[1] << 8
t0 = c.cpu.processorCycles
c.tap("q", ms=100)
c.run_ms(int(beat * 0.75 * 6))
m = since(c, t0)
ech = [(t, s, a, b) for t, s, a, b in m if s in (0x9B, 0x91) and b]
check("ECHO PLUCK: five echoes on GB pulse 2 / NES pulse 2 in turn", [s for _, s, _, _ in ech] == [0x9B, 0x91, 0x9B, 0x91, 0x9B],
      [(hex(s), b) for _, s, _, b in ech])
gaps = [(b[0] - a[0]) / CYCLES_PER_MS for a, b in zip(ech, ech[1:])]
check("... every 3/4 beat", all(abs(g - beat * 0.75) <= 6 for g in gaps), [round(g) for g in gaps])
vel = [b for _, _, _, b in ech]
check("... each 70 % of the last", all(abs(y - x * 0.7) <= 2 for x, y in zip([100] + vel, vel)), vel)
pad = [s & 15 for _, s, a, b in m if (s & 0xF0) == 0x90 and b and (t0 < _ < t0 + 60 * CYCLES_PER_MS)]
check("the echo voices sit out of the chord", 11 not in pad and 1 not in pad and 10 in pad, pad)
c.run_ms(400)
check("echoes done: nothing left on", notes_on(c.midi()) == {} if "notes_on" in globals() else True)

check("REPEAT LEAD", sound_to("REPEAT LEAD"), c.screen_row(2))
t0 = c.cpu.processorCycles
c.tap("e", ms=100)
c.run_ms(beat * 2)
ech = [b for t, s, a, b in since(c, t0) if s in (0x9B, 0x91) and b]
check("REPEAT LEAD: three echoes at full volume (1/8)", ech == [100, 100, 100], ech)

# held notes come first
check("FAT", sound_to("FAT"), c.screen_row(2))
c.set("rpLock", 1)
c.set("repeatOn", 1)
c.set("reallocFlag", 1)
c.run_ms(60)
check("REPEAT ON in FAT: two echo voices", sum(c.v("vEcho", 9)) == 2)
keys = ["q", "w", "e", "r", "t", "y", "u", "i"]
c.press(*keys, ms=200)
check("8 notes held: the echo voices go back to the chord (held notes first)", sum(c.v("vEcho", 9)) == 0, c.v("vEcho", 9))
c.release(*keys, ms=200)
c.set("rpLock", 0)
c.set("repeatOn", 0)
c.set("reallocFlag", 1)

# the REPEAT action
c.set("spaceAct", 11)
t0 = c.cpu.processorCycles
c.press("space", ms=20)
c.tap("q", ms=50)
c.run_ms(1500)
c.release("space", ms=50)
ech = [b for t, s, a, b in since(c, t0) if s in (0x9B, 0x91) and b]
check("SPACE = REPEAT: echoes while held", len(ech) >= 2, ech)
c.set("spaceAct", 1)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
