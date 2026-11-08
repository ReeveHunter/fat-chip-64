#!/usr/bin/env python3
"""Fat Chip 64 v0.12: channels (Game Boy 11-15 set by CC 113, MidiNES 1-5),
the Chip Lab sounds (V), MONO (C), Fat Bass, SID effects, the keytar's drums
(MIDI in channel 16) and the beat demos (G, RETURN)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

fails = 0
GB = (10, 11, 12)          # pulse 1, pulse 2, wave
NES = (0, 1, 2, 3, 4)      # pulse 1, pulse 2, triangle, noise, samples
NOISE, DMC = 3, 4


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


def since(c, t0):
    return [(t, s, a, b) for t, s, a, b in c.midi(since=t0)]


def sound(c, name):
    """V (or SHIFT+V) until the sound line shows `name`."""
    for _ in range(20):
        if c.screen_row(1)[2:18].rstrip() == name:
            return True
        c.tap("v", ms=300)
    return False


def sid_freq(c, v):
    return c.sid(v)[0]


def longest_pass(c, n=60):
    loop = c.sym["Loop"]
    last, out = c.cpu.processorCycles, []
    while len(out) < n:
        c.step()
        if c.cpu.pc == loop:
            now = c.cpu.processorCycles
            out.append((now - last) / CYCLES_PER_MS)
            last = now
    return max(out)


# ---------------------------------------------------------------- channels
c = C64(channels=None)
c.run_ms(400)
m = c.midi()
first = m[0]
check("startup: the first message moves the Game Boy to 11-15 (CC 113 = 74 on ch 11)",
      first[1:] == (0xBA, 113, 74), first)
gb = [(s, a, b) for _, s, a, b in m if (s & 15) in GB]
check("startup: the Game Boy setup follows on ch 11", gb[1] == (0xBA, 102, 70), gb[:3])
nes7 = [(s & 15, b) for _, s, a, b in m if (s & 0xF0) == 0xB0 and a == 7 and (s & 15) in NES]
check("startup: MidiNES set up on channels 1-5", [ch for ch, _ in nes7[:5]] == [0, 1, 2, 3, 4], nes7)
check("startup: sample channel at full pitch (CC3 = 127 on ch 5)", (0xB4, 3, 127) in [x[1:] for x in m])
check("screen: Game Boy CH 11-15, MidiNES CH 1-5, no overlap warning",
      c.screen_row(4).rstrip().endswith("CH 11-15") and c.screen_row(5).rstrip().endswith("CH 1-5")
      and "OVERLAP" not in c.screen_row(7), (c.screen_row(4), c.screen_row(5)))
check("screen: header V0.13, sound line, beat line",
      "V0.13" in c.screen_row(0) and c.screen_row(1).startswith("V FAT ") and "POLY" in c.screen_row(1)
      and "FAT BASS" in c.screen_row(1) and c.screen_row(23).rstrip().endswith("G ELECTRO  STOP"),
      (c.screen_row(1), c.screen_row(23)))
t0 = c.cpu.processorCycles
c.press("ctrl", ms=12)
c.tap("f3", ms=40)
c.release("ctrl", ms=150)
cc113 = [x[1:] for x in since(c, t0) if x[2] == 113]
check("CTRL+F3: the Game Boy follows to 12-16 (CC 113 = 75)", cc113 and cc113[0][2] == 75, cc113)
for _ in range(11):                          # 13-17.. wraps to 1-5 ... back to 11-15
    c.press("ctrl", ms=12); c.tap("f3", ms=12); c.release("ctrl", ms=12)
c.run_ms(400)
check("CTRL+F3 round the block: back on 11-15", c.v("gbBase") == 10, c.v("gbBase"))

# ---------------------------------------------------------------- Fat Bass
c.run_ms(200)
t0 = c.cpu.processorCycles
c.press("o", ms=120)                         # D4 (62) with Q = C3
on = notes_on(c.midi())
check("Fat Bass (FAT): D4 -> bass D2 (38) on the GB wave and NES triangle", on.get(12) == 38 and on.get(2) == 38, on)
c.release("o", ms=80)
check("all off", notes_on(c.midi()) == {}, notes_on(c.midi()))

# ---------------------------------------------------------------- sounds
names = []
for i in range(19):
    c.run_ms(300)
    names.append(c.screen_row(1)[2:18].rstrip())
    c.tap("v", ms=20)
c.run_ms(200)
check("V steps through 19 sounds and back to FAT", len(set(names)) == 19 and c.screen_row(1).startswith("V FAT "), names)
c.press("lshift", ms=12)
c.tap("v", ms=150)
c.release("lshift", ms=12)
check("SHIFT+V: previous (TREMOLO GATE)", c.screen_row(1)[2:18].rstrip() == "TREMOLO GATE", c.screen_row(1))

# whistle: mono default, no Fat Bass: the wave and triangle play the tune
check("WHISTLE", sound(c, "WHISTLE"), c.screen_row(1))
check("WHISTLE: MONO, no Fat Bass", c.v("monoMode") == 1 and c.v("fatBass") == 0 and "MONO" in c.screen_row(1)
      and "FAT BASS" not in c.screen_row(1), c.screen_row(1))
t0 = c.cpu.processorCycles
c.press("q", ms=150)
on = notes_on(c.midi())
check("WHISTLE: one note on every voice, the wave and triangle at pitch", set(on.values()) == {48} and 12 in on and 2 in on, on)
legcc = [x[1:] for x in c.midi() if x[2] == 68 and (x[1] & 15) in GB]
check("MONO: Game Boy legato on (CC 68 = 127)", legcc[-3:] == [(0xBA, 68, 127), (0xBB, 68, 127), (0xBC, 68, 127)], legcc[-3:])
f = []
for _ in range(25):
    c.run_ms(20)
    f.append(sid_freq(c, 0))
check("WHISTLE: SID vibrato after the delay", len(set(f[:8])) <= 2 and len(set(f[15:])) >= 4, f)
gate_before = c.sid(0)[1]
t0 = c.cpu.processorCycles
c.press("e", ms=150)                         # E3 while C3 is held: legato
msgs = since(c, t0)
on = notes_on(c.midi())
check("MONO: the last key (E3) on every voice", set(on.values()) == {52}, on)
gbm = [(s >> 4, a) for _, s, a, b in msgs if (s & 15) == 10 and (s & 0xF0) in (0x80, 0x90)]
check("MONO legato, Game Boy: new note-on before the old note-off", gbm[:2] == [(9, 52), (8, 48)], gbm)
check("MONO legato: SID not re-attacked", c.sid(0)[1] & 1 == 1 and gate_before & 1 == 1 and c.v("vRetrig", 9) == [0] * 9)
nes7 = [b for _, s, a, b in msgs if s == 0xB0 and a == 7]
check("MONO legato, NES: the envelope carries on (no CC7 = 0)", 0 not in nes7, nes7)
c.release("e", ms=150)
check("MONO: letting go of E3 goes back to C3", set(notes_on(c.midi()).values()) == {48}, notes_on(c.midi()))
c.tap("c", ms=150)
check("C: POLY", c.v("monoMode") == 0 and "POLY" in c.screen_row(1), c.screen_row(1))
c.release("q", ms=600)
check("WHISTLE released: all off (after the NES release)", notes_on(c.midi()) == {}, notes_on(c.midi()))

# glide bass: the SID slides
check("GLIDE BASS", sound(c, "GLIDE BASS"), c.screen_row(1))
c.press("q", ms=120)
fq = sid_freq(c, 0)
c.press("t", ms=8)                          # G3 while C3 held
path = []
for _ in range(12):
    c.run_ms(10)
    path.append(sid_freq(c, 0))
check("GLIDE BASS: the SID glides up to G3 over tens of ms", path[0] < path[-1] and len(set(path)) >= 5 and path[0] > fq * 0.99,
      (fq, path))
c.release("t", "q", ms=200)

# duty lead: the duty steps on the SID and the NES
check("DUTY LEAD", sound(c, "DUTY LEAD"), c.screen_row(1))
t0 = c.cpu.processorCycles
c.press("q", ms=10)
pw = set()
for _ in range(30):
    c.run_ms(8)
    pw.add(c.raw[0xD403])
duty = [b for _, s, a, b in since(c, t0) if s in (0xB0, 0xB1) and a == 1]
check("DUTY LEAD: SID widths step 12.5 / 25 / 50%", pw >= {2, 4, 8}, pw)
check("DUTY LEAD: NES duty steps (CC1)", {0, 32, 64} <= set(duty), duty[:12])
c.release("q", ms=300)

# electric piano: NES tremolo through CC7
check("ELECTRIC PIANO", sound(c, "ELECTRIC PIANO"), c.screen_row(1))
c.press("q", ms=1200)
t0 = c.cpu.processorCycles
c.run_ms(400)
lv = [b for _, s, a, b in since(c, t0) if s == 0xB0 and a == 7]
check("ELECTRIC PIANO: NES tremolo keeps moving CC7 while held", len(set(lv)) >= 2 and len(lv) >= 4, lv)
c.release("q", ms=1500)

# screamer: filter opens on the attack and falls back; the busiest sound stays quick
check("SCREAMER", sound(c, "SCREAMER"), c.screen_row(1))
c.press("q", ms=20)
f1 = c.raw[0xD416]
c.run_ms(400)
f2 = c.raw[0xD416]
check("SCREAMER: filter envelope opens and falls back", f1 > f2 >= 0x14, (f1, f2))
lp = longest_pass(c)
check("SCREAMER held: longest main loop pass under 4.7 ms", lp < 4.7, f"{lp:.2f} ms")
c.release("q", ms=200)

# switching sounds while holding: nothing hangs
check("BRIGHT? no: WARBLE PAD", sound(c, "WARBLE PAD"), c.screen_row(1))
c.press("q", "t", ms=200)
c.tap("v", ms=200)
c.tap("v", ms=200)
c.release("q", "t", ms=2500)
check("sound changes while holding: nothing left on", notes_on(c.midi()) == {}, notes_on(c.midi()))

# ---------------------------------------------------------------- keytar drums (MIDI in ch 16)
c.set("syncDrums", 1)                        # v0.13: the menu's DRUM NOTES = PLAY (default IGNORE)
t0 = c.cpu.processorCycles
c.midi_in(0x9F, 45, 127, ms=20)              # kick accent
c.midi_in(0x9F, 57, 64, ms=20)               # hat
msgs = since(c, t0)
dmc = [x[1:] for x in msgs if (x[1] & 15) == DMC]
check("keytar kick (accent): bank A (CC14 = 0), sample A0 (ELECTRO kit)",
      (0xB4, 14, 0) in dmc and (0x94, 0, 127) in dmc, dmc)
nz = [x[1:] for x in msgs if (x[1] & 15) == NOISE]
check("keytar hat: NES noise level (CC7) and a closed-hat note 49-51",
      any(s == 0xB3 and a == 7 for s, a, _ in nz) and any(s == 0x93 and 49 <= a <= 51 for s, a, _ in nz), nz)
c.run_ms(60)
offs = [x for x in since(c, t0) if x[1] == 0x83 or (x[1] == 0x93 and x[3] == 0)]
check("keytar hat: noise note-off after ~45 ms", len(offs) == 1, offs)
t0 = c.cpu.processorCycles
c.midi_in(0x9F, 52, 56, ms=5)               # snare ghost
c.midi_in(0x9F, 45, 64, ms=20)              # a kick 2 ms later: more important, plays
d = [x[1:] for x in since(c, t0) if (x[1] & 0xF0) == 0x90 and (x[1] & 15) == DMC and x[3]]
check("keytar snare ghost (A65), then a kick right after it still plays (A10)", d == [(0x94, 65, 127), (0x94, 10, 127)], d)
t0 = c.cpu.processorCycles
c.midi_in(0x9F, 45, 64, ms=2)
c.midi_in(0x9F, 52, 64, ms=20)              # snare 2 ms after a kick: dropped
d = [x[1:] for x in since(c, t0) if (x[1] & 0xF0) == 0x90 and (x[1] & 15) == DMC and x[3]]
check("a snare right after a kick is dropped (one sample at a time)", d == [(0x94, 10, 127)], d)
t0 = c.cpu.processorCycles
c.midi_in(0x9B, 60, 64, 0x9E, 36, 64, ms=40)   # accompaniment channels: still ignored
check("channels 12-15 still ignored", since(c, t0) == [], since(c, t0))
c.midi_in(0x8B, 60, 0, 0x8E, 36, 0, ms=20)

# ---------------------------------------------------------------- beat demos
c.tap("g", ms=150)
check("G: JUNGLE, 168 BPM", c.v("beatSel") == 1 and c.v("bpm") == 168 and "JUNGLE" in c.screen_row(23), c.screen_row(23))
t0 = c.cpu.processorCycles
c.tap("return", ms=10)
c.run_ms(2 * 4 * 60000 // 168 + 50)          # two bars
msgs = since(c, t0)
kicks = [t for t, s, a, b in msgs if s == 0x94 and b and a in (10, 12, 112)]       # B10 / B12 / A112 (bank B: & 127)
samples = [(t, a) for t, s, a, b in msgs if s == 0x94 and b]
hats = [t for t, s, a, b in msgs if s == 0x93 and b and 49 <= a <= 51]
check("RETURN: JUNGLE plays samples and noise hats", len(samples) >= 10 and len(hats) >= 12, (len(samples), len(hats)))
banks = [b for t, s, a, b in msgs if s == 0xB4 and a == 14]
check("JUNGLE: its kit switches the sample bank as needed", 127 in banks, banks)
step = 60000 / 168 / 4
ht = [(t - hats[0]) / CYCLES_PER_MS for t in hats]
hd = [b - a for a, b in zip(ht, ht[1:])]
check("JUNGLE hats on the 16th grid (89 ms): gaps within 8 ms (MidiNES queue), no drift",
      all(abs(g - round(g / step) * step) <= 8 for g in hd) and abs(ht[-1] - round(ht[-1] / step) * step) <= 6,
      [round(x) for x in ht[:8]])
check("screen: PLAY", c.screen_row(23).rstrip().endswith("JUNGLE   PLAY"), c.screen_row(23))
c.tap("return", ms=150)
check("RETURN again: stops (screen STOP)", c.v("beatRun") == 0 and "STOP" in c.screen_row(23), c.screen_row(23))
t0 = c.cpu.processorCycles
c.run_ms(400)
check("stopped: no more drums", [x for x in since(c, t0) if (x[1] & 0xF0) == 0x90 and x[3]] == [])

# boombap: swing
c.tap("g", ms=20); c.tap("g", ms=150)
check("G G: BOOMBAP, 90 BPM", c.v("beatSel") == 3 and c.v("bpm") == 90, (c.v("beatSel"), c.v("bpm")))
t0 = c.cpu.processorCycles
c.tap("return", ms=10)
c.run_ms(2 * 4 * 60000 // 90 + 50)
msgs = since(c, t0)
hits = [(t - t0) / CYCLES_PER_MS for t, s, a, b in msgs if s == 0x94 and b]
rel = [round(x - hits[0]) for x in hits]
# bar 1 samples: steps 0 K, 4 S, 7 K (odd: swung), 10 K, 12 S, 15 K (odd); step 166.7 ms, swing 55% = +46 ms
check("BOOMBAP: odd 16ths swung late (+46 ms), even ones on the grid",
      len(rel) >= 6 and abs(rel[1] - 667) <= 6 and abs(rel[2] - 1213) <= 8 and abs(rel[3] - 1667) <= 6, rel[:6])
c.tap("return", ms=50)

# panic stops a beat
c.tap("return", ms=200)
c.press("lshift", ms=10); c.tap("f7", ms=40); c.release("lshift", ms=10)
t0 = c.cpu.processorCycles
c.run_ms(500)
check("SHIFT+F7 panic stops the beat", c.v("beatRun") == 0 and not [x for x in since(c, t0) if (x[1] & 0xF0) == 0x90 and x[3]])

# NES off: the drums go quiet
c.press("lshift", ms=10); c.tap("f5", ms=40); c.release("lshift", ms=100)
t0 = c.cpu.processorCycles
c.midi_in(0x9F, 45, 127, 0x9F, 57, 64, ms=60)
check("NES off: keytar drums send nothing", since(c, t0) == [], since(c, t0))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
