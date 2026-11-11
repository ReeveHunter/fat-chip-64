#!/usr/bin/env python3
"""Fat Chip 64 v0.16: the MIDI chip's interrupts (with the polling fallback
when they don't reach the C64) and the quicker keyboard scan."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def ticks(c):
    t = c.v("ticks", 2)
    return t[0] | t[1] << 8


def clocks(c, bpm, beats):
    per = 60000 / bpm / 24 * CYCLES_PER_MS
    t = max(c.cpu.processorCycles, c.rx_last) + 400
    for i in range(int(beats * 24)):
        c.rx_q.append((int(t + i * per), 0xF8))
    c.rx_q.sort()
    c.rx_last = c.rx_q[-1][0]


def passes(c, ms):
    """Main loop passes (Loop reached) in the next ms, and the longest, ms."""
    L = c.sym["Loop"]
    end = c.cpu.processorCycles + ms * CYCLES_PER_MS
    n, last, longest = 0, c.cpu.processorCycles, 0
    while c.cpu.processorCycles < end:
        if c.cpu.pc == L:
            longest = max(longest, c.cpu.processorCycles - last)
            last = c.cpu.processorCycles
            n += 1
        c.step()
    return n, longest / CYCLES_PER_MS


for wired in (True, False):
    tag = "MIDI interrupts" if wired else "no MIDI interrupts (polling)"
    c = C64(channels=None, acia_irq=wired)
    c.run_ms(300)
    check(f"{tag}: found at start (midiIrq {int(wired)})", c.v("midiIrq") == int(wired), c.v("midiIrq"))
    check(f"{tag}: no RESTORE press counted from the test", c.v("nmiCount") == 0)
    t0 = ticks(c)
    c.run_ms(1000)
    check(f"{tag}: the ms tick keeps time (1000 a second)", abs(ticks(c) - t0 - 1000) <= 2, ticks(c) - t0)
    t0 = c.cpu.processorCycles
    c.press("q", "e", "t", ms=150)
    out = [(s, a, b) for _, s, a, b in c.midi(since=t0)]
    check(f"{tag}: a chord goes out to the Game Boy and NES", any((st, 48, 100) in out for st in (0x9A, 0x9B, 0x9C)) and (0x90, 48, 100) in out, out[:6])
    gaps = [(b[0] - a[0]) for a, b in zip(c.tx, c.tx[1:]) if a[0] >= t0]
    check(f"{tag}: bytes back to back are a byte time apart (or more)", gaps and min(gaps) >= 327, min(gaps) if gaps else gaps)
    c.release("q", "e", "t", ms=150)
    c.midi_in(0x90, 62, 100, 0x90, 64, 100, 0x90, 67, 100, ms=60)
    check(f"{tag}: MIDI in: a chord received", c.v("heldCount") == 3 and c.rx_overrun == 0, (c.v("heldCount"), c.rx_overrun))
    c.midi_in(0x80, 62, 0, 0x80, 64, 0, 0x80, 67, 0, ms=100)
    clocks(c, 123, 6)
    c.run_ms(int(6 * 60000 / 123) + 300)
    check(f"{tag}: keytar clock at 123 BPM followed", c.v("bpm") == 123, c.v("bpm"))
    # a burst: 40 bytes in a row in, while sending
    c.press("q", "w", "e", "r", ms=5)
    c.midi_in(*([0xF8] * 40), ms=100)
    check(f"{tag}: a 40-byte burst in while sending: nothing lost", c.rx_overrun == 0, c.rx_overrun)
    c.release("q", "w", "e", "r", ms=200)

# ---------------------------------------------------------------- speed
c = C64(channels=None)
c.run_ms(300)
c.midi_in(0xC0, 4, ms=300)                     # WHISTLE: SID and NES vibrato
c.press("q", "e", "t", ms=300)
n, longest = passes(c, 300)
check("MIDI interrupts: main loop passes in 300 ms with a chord held (were about 80)", n > 160, n)
check("... the longest under 4 ms", longest < 4.0, round(longest, 2))
c.release("q", "e", "t", ms=200)

c2 = C64(channels=None, acia_irq=False)
c2.run_ms(300)
c2.midi_in(0xC0, 4, ms=300)
c2.press("q", "e", "t", ms=300)
n2, _ = passes(c2, 300)
check("polling: still more passes than v0.15 (the quicker keyboard scan)", n2 > 90, n2)

# keyboard: nothing changed is quick, a change still lands
c.press("a", ms=100)
k = c.sym["KeyScan"]
cyc = []
for _ in range(3):
    c.run_until(k)
    t0 = c.cpu.processorCycles
    sp = c.cpu.sp
    c.step()
    while not (c.cpu.sp == sp and c.raw[c.cpu.pc - 1] == 0x60 and c.cpu.pc != k):
        c.step()
        if c.cpu.processorCycles - t0 > 5000:
            break
    cyc.append(c.cpu.processorCycles - t0)
check("a scan with nothing changed (a key held) is quick (about half a ms, was over 1)", max(cyc) < 600, cyc)
c.release("a", ms=60)
c.tap("z", ms=60)
check("... and a key press still works (Z: notes mode)", c.v("playMode") == 1, c.v("playMode"))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
