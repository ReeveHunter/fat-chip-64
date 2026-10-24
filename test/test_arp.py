#!/usr/bin/env python3
"""Fat Chip 64 v0.05: tap tempo and the arpeggiator."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def ons(c, ch, since):
    """(ms, note) of note-ons on MIDI channel ch (0-based) since cycle `since`."""
    return [(cyc / CYCLES_PER_MS, a) for cyc, s, a, b in c.midi(since=since) if s == 0x90 | ch and b]


def gaps(ev):
    return [round(b[0] - a[0], 1) for a, b in zip(ev, ev[1:])]


c = C64()
c.run_ms(150)
check("arp line on screen", c.screen_row(19).startswith("A ARP OFF") and "1/16" in c.screen_row(19)
      and "+1 OCT" in c.screen_row(19) and "120BPM" in c.screen_row(22).replace(" ", ""), c.screen_row(22))
check("Game Boy gets the tempo at startup (120 BPM = CC107 30, CC108 0)",
      [(a, b) for _, s, a, b in c.midi() if s == 0xB0 and a in (107, 108)] == [(107, 30), (108, 0)])

# ---------------------------------------------------------------- tap tempo
t0 = c.cpu.processorCycles
for _ in range(5):
    c.tap("b", ms=250)                      # 500 ms apart -> 120... make it 100 BPM:
c.run_ms(100)
t0 = c.cpu.processorCycles
for _ in range(5):
    c.press("b", ms=300)
    c.release("b", ms=300)                  # 600 ms apart = 100 BPM
c.run_ms(60)
check("tap tempo: 100 BPM", c.v("bpm") == 100 and "100BPM" in c.screen_row(22).replace(" ", ""),
      (c.v("bpm"), c.screen_row(22)))
tm = [(a, b) for _, s, a, b in c.midi(since=t0) if s == 0xB0 and a in (107, 108)]
check("tap tempo goes to the Game Boy (100 x 32 = 3200: CC107 25, CC108 0)", tm[-2:] == [(107, 25), (108, 0)], tm[-2:])
c.run_ms(2500)
c.tap("b", ms=50)
check("one tap after a long gap doesn't change the tempo", c.v("bpm") == 100)

# ---------------------------------------------------------------- unison arp
c.tap("a", ms=60)
check("A: UNISON", c.v("arpMode") == 1 and "UNISON" in c.screen_row(19), c.screen_row(19))
c.tap("d", ms=30)                           # 1/16 -> 1/32
c.tap("d", ms=30)                           # 1/32 -> FREE
c.tap("d", ms=30)                           # FREE -> 1/4
c.tap("d", ms=30)                           # 1/8
check("D steps the speed: 1/8", c.v("arpLen") == 1 and "1/8 " in c.screen_row(19), c.screen_row(19))
t0 = c.cpu.processorCycles
c.press("q", "e", "t", ms=1700)             # C E G held
ev = ons(c, 0, t0)
notes = [n for _, n in ev]
check("UP: C E G C E G ...", notes[:6] == [48, 52, 55, 48, 52, 55], notes)
g = gaps(ev)
check("1/8 at 100 BPM = 300 ms per step (on the wire, within the Game Boy queue's few ms)",
      all(abs(x - 300) <= 12 for x in g) and abs(sum(g) / len(g) - 300) < 3, g)
nes = [n for _, n in ons(c, 5, t0)]
check("unison: the NES plays the same notes", nes[:6] == notes[:6], nes)
sid_gates = c.sid(0)[1] & 1
check("unison: the SID plays too", sid_gates == 1)
bass = [n for _, n in ons(c, 2, t0)]
check("unison: GB wave follows an octave down", bass[:3] == [36, 40, 43], bass)

t0 = c.cpu.processorCycles
c.tap("s", ms=20)                           # DOWN: from the top at the next step
c.run_ms(1000)
notes = [n for _, n in ons(c, 0, t0)]
check("S: DOWN goes G E C", "DOWN" in c.screen_row(19) and notes[:3] == [55, 52, 48], notes)
c.tap("s", ms=10)                           # UP-DOWN
t0 = c.cpu.processorCycles
c.run_ms(2200)
notes = [n for _, n in ons(c, 0, t0)]
check("UP-DOWN: C E G E C E G (no repeats at the ends)", notes[:7] == [48, 52, 55, 52, 48, 52, 55], notes)
c.tap("s", ms=10)                           # RANDOM
t0 = c.cpu.processorCycles
c.run_ms(4000)
notes = [n for _, n in ons(c, 0, t0)]
check("RANDOM: only chord notes, never the same twice in a row, all three used",
      set(notes) == {48, 52, 55} and all(a != b for a, b in zip(notes, notes[1:])), notes)
c.release("q", "e", "t", ms=60)
check("release: arp stops, nothing left on", all(v == 255 for v in c.v("vNote", 9)), c.v("vNote", 9))

c.tap("s", ms=40)                           # AS PLAYED
check("S: PLAYED", "PLAYED" in c.screen_row(19), c.screen_row(19))
c.tap("=", ms=30)                           # latch SMART
c.tap("=", ms=30)                           # HOLD
c.tap("=", ms=30)                           # ADD
t0 = c.cpu.processorCycles
for k in ("t", "q", "y", "e"):              # G C A E, one at a time
    c.tap(k, ms=40)
c.run_ms(2600)
notes = [n for _, n in ons(c, 0, t0)][-8:]
check("PLAYED + ADD latch: the order you built it (G C A E)", notes[:4] in ([55, 48, 57, 52], [48, 57, 52, 55], [57, 52, 55, 48], [52, 55, 48, 57]), notes)
c.tap("n", ms=20); c.tap("n", ms=60)
check("N: chord gone, arp stopped", all(v == 255 for v in c.v("vNote", 9)))

# ---------------------------------------------------------------- free speed
c.tap("s", ms=10)                           # UP again
c.tap("h", ms=30)                           # picks FREE (160 ms)
c.run_ms(40)
check("H picks FREE", "160MS" in c.screen_row(19).replace(" ", ""), c.screen_row(19))
c.tap("j", ms=30)
c.tap("j", ms=30)                           # 110 ms
c.run_ms(60)
check("J faster: 110 MS", "110MS" in c.screen_row(19).replace(" ", ""), c.screen_row(19))
t0 = c.cpu.processorCycles
c.tap("q", ms=30); c.tap("w", ms=30)
c.run_ms(1200)
g = gaps(ons(c, 0, t0))
check("FREE 110 ms steps", g and all(abs(x - 110) <= 5 for x in g[2:]), g)
c.tap("n", ms=20); c.tap("n", ms=40)

# ---------------------------------------------------------------- sparkle
t0 = c.cpu.processorCycles
c.tap("a", ms=60)
check("A again: SPARKLE", "SPARKLE" in c.screen_row(19), c.screen_row(19))
pans = [(s & 15, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0 and a == 10]
check("sparkle pans the Game Boy pulses left / right", pans == [(0, 0), (1, 127)], pans)
t0 = c.cpu.processorCycles
c.tap("q", ms=20); c.tap("e", ms=20); c.tap("t", ms=20)   # C E G built
c.run_ms(1500)
p1 = [n for _, n in ons(c, 0, t0)]
p2 = [n for _, n in ons(c, 1, t0)]
allp = sorted(ons(c, 0, t0) + ons(c, 1, t0))
chans = []
for ms, n in allp:
    chans.append(0 if (ms, n) in ons(c, 0, t0) else 1)
check("sparkle: the arp ping-pongs between pulse 1 and pulse 2", chans[2:8] in ([0, 1, 0, 1, 0, 1], [1, 0, 1, 0, 1, 0]), chans)
check("sparkle: the arp walks the chord an octave up", [n - 12 for _, n in allp][2:8] in
      ([55, 48, 52, 55, 48, 52], [52, 55, 48, 52, 55, 48], [48, 52, 55, 48, 52, 55]), [n for _, n in allp])
on_pad = {}
for _, s, a, b in c.midi():
    ch = s & 15
    if (s & 0xF0) == 0x90 and b:
        on_pad[ch] = a
    elif (s & 0xF0) == 0x80 and on_pad.get(ch) == a:
        del on_pad[ch]
check("sparkle: the NES and GB wave hold the pad", on_pad.get(5) in (48, 52, 55) and on_pad.get(6) in (48, 52, 55)
      and on_pad.get(2) == 36, on_pad)
nes_ons = len(ons(c, 5, c.cpu.processorCycles - 800 * CYCLES_PER_MS))
check("sparkle: the pad doesn't re-attack every step", nes_ons == 0, nes_ons)
c.tap("n", ms=20); c.tap("n", ms=60)
t0 = c.cpu.processorCycles
c.tap("a", ms=60)                           # OFF
pans = [(s & 15, b) for _, s, a, b in c.midi(since=t0) if (s & 0xF0) == 0xB0 and a == 10]
check("arp off: pulses back to centre", pans == [(0, 64), (1, 64)], pans)
c.tap("=", ms=40)                           # latch off (ADD -> OFF)
t0 = c.cpu.processorCycles
c.press("q", ms=300)
on = [x for x in c.midi(since=t0) if (x[1] & 0xF0) == 0x90 and x[3]]
check("arp off: plain notes again (one note-on per voice, no stepping)", len(on) == 6, len(on))
c.release("q", ms=60)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
