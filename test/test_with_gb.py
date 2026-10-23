#!/usr/bin/env python3
"""End to end: Fat Chip 64 (py65) -> MIDI bytes -> Fat Chip GB (PyBoy).

Runs Fat Chip 64: a chord, a RESTORE double tap, fast messy playing, a
minute of silence, more notes, then SHIFT+F7 panic with keys held. The exact
bytes it sent go through a model of the Teensyboy (teensy.py, timing and
buffer from its firmware) into the Fat Chip GB ROM at their real times.
Needs the fat-chip-gb repo next to this one (FATCHIP_GB=path to override).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim import C64, CYCLES_PER_MS, OVERLAY  # noqa: E402
from teensy import forward  # noqa: E402
import random  # noqa: E402

GB_REPO = os.environ.get("FATCHIP_GB", os.path.join(HERE, "..", "..", "fat-chip-gb"))
sys.path.insert(0, os.path.join(GB_REPO, "test"))
from harness import GB  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


# ---------------------------------------------------------------- the C64 side
c = C64()
c.run_ms(150)
c.press("q", "e", "t", ms=120)          # C-E-G chord, held
t_chord = c.cpu.processorCycles
c.run_ms(200)
c.restore(); c.run_ms(100); c.restore(); c.run_ms(100)   # double tap: Game Boy screen off
c.release("q", "e", "t", ms=200)
rnd = random.Random(3)
for _ in range(40):                     # fast, messy playing
    ks = rnd.sample(list(OVERLAY), rnd.randint(1, 4))
    c.press(*ks, ms=rnd.choice((4, 12, 40)))
    c.release(*ks, ms=rnd.choice((4, 20)))
c.run_ms(300)
t_quiet = c.cpu.processorCycles
# a minute of silence (v0.1 froze its queues after 33 s): skip the clock ahead
t = (c.v("ticks") | (c.v("ticks", 2)[1] << 8)) + 60000
c.raw[c.sym["ticks"]], c.raw[c.sym["ticks"] + 1] = t & 255, (t >> 8) & 255
c.press("r", ms=80); c.release("r", ms=80)
c.press("q", "w", ms=100)               # held through the panic
t_panic = c.cpu.processorCycles
c.press("lshift", ms=10); c.tap("f7", ms=30); c.release("lshift", ms=10)
c.run_ms(200)
late = [m for m in c.midi(since=t_quiet) if m[1] == 0x90 and m[2] == 53]
check("after a minute of silence the next note still reaches the Game Boy at once", late != [], late)
wire, lost = forward(list(c.tx))
check("Teensyboy model: nothing lost", lost == 0, lost)

# ---------------------------------------------------------------- replay into the Game Boy
gb = GB(os.path.join(GB_REPO, "fat-chip-gb.gb"), sram=bytes(8192))
gb.run(120)
FRAME = CYCLES_PER_MS * 1000 / 59.7275   # C64 cycles per GB frame
t0 = wire[0][0]
frame = 0
i = 0
chord_frame = None
quiet_frame = None
quiet_sound = None
while i < len(wire):
    limit = t0 + (frame + 1) * FRAME
    chunk = []
    while i < len(wire) and wire[i][0] < limit:
        chunk.append(wire[i][1])
        if chord_frame is None and wire[i][0] >= t_chord:
            chord_frame = frame
        i += 1
    if chunk:
        gb.midi(*chunk)
    gb.run(1)
    frame += 1
    if quiet_frame is None and i < len(wire) and wire[i][0] >= t_quiet:
        quiet_frame = frame
        vs = gb.sym["_voice"]
        quiet_sound = [(gb.mem(vs + v * 45 + 2), gb.mem(vs + v * 45 + 30)) for v in range(3)]  # gate, env stage
    if chord_frame is not None and frame == chord_frame + 2:
        # snapshot while the chord is held, before the screen-off taps
        vs = gb.sym["_voice"]
        notes = [gb.mem(vs + v * 45) for v in range(3)]
        sounding = gb.mem(0xFF26)
gb.run(10)
gb.run(60)
vs = gb.sym["_voice"]
after_panic = [(gb.mem(vs + v * 45 + 2), gb.mem(vs + v * 45 + 30)) for v in range(3)]

check("Game Boy switched to the FAT CHIP profile", gb.var("_profile") == 1)
check("warble depth from Fat Chip 64", gb.var("_warble_amt") == 24, gb.var("_warble_amt"))
patch = gb.sym["_patch"]
P_DETUNE = 10
check("pulses detuned about -5 / +5 cents (patch 29 / 35)", (gb.mem(patch + P_DETUNE), gb.mem(patch + 32 + P_DETUNE)) == (29, 35),
      (gb.mem(patch + P_DETUNE), gb.mem(patch + 32 + P_DETUNE)))
check("chord on the Game Boy: pulse 1 G3, pulse 2 C3, wave C2 (bass)", notes == [55, 48, 36], notes)
check("all three Game Boy voices sounding", sounding & 0x07 == 0x07, hex(sounding))
check("double RESTORE turned the Game Boy screen off", not (gb.mem(0xFF40) & 0x80))
check("no stray bytes on the Game Boy side", gb.var("_lt_stray", 2) == [0, 0])
check("after fast playing every Game Boy note was released (gate off, releasing or idle)",
      all(g == 0 and st in (0, 3) for g, st in quiet_sound), quiet_sound)
check("SHIFT+F7 with keys held: every Game Boy voice silent (idle)", after_panic == [(0, 0)] * 3, after_panic)
gb.stop()
print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
