#!/usr/bin/env python3
"""Fat Chip 64 v0.31: BEND OUT on every chip: the Game Boy's own release
drop (CC 87 / 88), the NES bending while its envelope fades, and a fall-off
(the note held for TIME as it falls) when the NES has no envelope."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from sim import C64, CYCLES_PER_MS  # noqa: E402
import gen_patches  # noqa: E402

fails = 0
P = gen_patches.PATCHES


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def send(c, base, **fx):
    p = copy.deepcopy(P[base])
    p["fatBass"] = 0
    p["fx"].pop("detune", None)
    p["fx"].pop("warble", None)
    p["fx"].update(fx)
    n0 = c.v("sxCount")
    c.midi_in(*gen_patches.sysex(p), ms=250)
    assert c.v("sxCount") == (n0 + 1) & 255, "SysEx not taken"


def note(c, n, on=True, ms=0):
    c.midi_in(0x90 if on else 0x80, n, 100 if on else 0, ms=ms)


def nes_events(c, t0, ch):
    """(ms after t0, kind, value): bends (signed from centre) and note-offs on NES channel ch."""
    out = []
    for t, s, a, b in c.midi():
        if t < t0 or s & 15 != ch:
            continue
        ms = (t - t0) / CYCLES_PER_MS
        if s & 0xF0 == 0xE0:
            out.append((ms, "bend", (b << 7 | a) - 8192))
        elif s & 0xF0 == 0x80 or (s & 0xF0 == 0x90 and b == 0):
            out.append((ms, "off", a))
    return out


c = C64(channels=None)
c.run_ms(400)
check("header V0.31", "V0.31" in c.screen_row(0), c.screen_row(0))
nes1 = c.v("nesBase")                    # NES pulse 1's channel

# ---------------------------------------------------------------- Game Boy: CC 87 / 88
t0 = c.cpu.processorCycles
send(c, 2, rdrop={"amount": 7, "time": 300})
gbb = c.v("gbBase")
cc = {(s & 15, a): b for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a in (87, 88)}
check("Game Boy: CC 87 = 7 semitones on its channels", all(cc.get((gbb + i, 87)) == 7 for i in range(3)), cc)
check("... CC 88 a time (the nearest of its 16, x 8)", cc.get((gbb, 88), 0) > 0 and cc[(gbb, 88)] % 8 == 0, cc)
t0 = c.cpu.processorCycles
send(c, 2)
cc = {(s & 15, a): b for t, s, a, b in c.midi() if t >= t0 and s & 0xF0 == 0xB0 and a == 87}
check("... a patch without it: CC 87 0 (off)", cc.get((gbb, 87)) == 0, cc)

# ---------------------------------------------------------------- NES, no envelope (RAW): a fall-off
send(c, 2, rdrop={"amount": 12, "time": 300})
check("NES fields: amount 12, 30 steps of 10 ms", c.v("nesRdrop") == 12 and c.v("sndRdropT") == 30)
note(c, 60, ms=300)
t0 = c.cpu.processorCycles
note(c, 60, False, ms=600)
ev = nes_events(c, t0, nes1)
offs = [e for e in ev if e[1] == "off"]
bends = [e for e in ev if e[1] == "bend" and (not offs or e[0] < offs[0][0])]
check("fall-off: the NES note-off waits for TIME (about 300 ms)", offs and 280 <= offs[0][0] <= 340, offs[:2])
check("... and the note bends down meanwhile, an octave by the end",
      len(bends) >= 5 and bends[-1][2] < bends[0][2] and bends[-1][2] < -1200, [b[2] for b in bends][:12])
note(c, 60, ms=150)
ev = nes_events(c, t0, nes1)
check("... the next note's bend is back at centre", ev and ev[-1][1] == "bend" and abs(ev[-1][2]) < 200, ev[-3:])
check("... nothing left over", c.v("nesRd", 9)[2] == 0 and c.v("nesFoT", 9)[2] == 0 and c.v("foAny") == 0)
note(c, 60, False, ms=100)
c.midi_in(0xB0, 123, 0, ms=10)           # (MIDI panic, if Fat Chip takes it)
c.run_ms(600)

# a new note on the same voice while it falls: the fall-off ends there
t0 = c.cpu.processorCycles
note(c, 60, ms=200)
note(c, 60, False, ms=80)
note(c, 64, ms=100)
ev = nes_events(c, t0, nes1)
check("played again mid-fall: the old note's cut, the new one starts on pitch",
      c.v("nesFoT", 9)[2] == 0 and any(e[1] == "off" for e in ev), ev[-4:])
note(c, 64, False, ms=600)

# ---------------------------------------------------------------- NES with an envelope (PADS): bends while it fades
send(c, 1, rdrop={"amount": 5, "time": 300, "on": ["nes"]})
check("PADS, BEND OUT on the NES only: the SID and Game Boy have none", c.v("sndRdrop") == 0 and c.v("gbRdA") == 0
      and c.v("nesRdrop") == 5)
note(c, 60, ms=1200)
t0 = c.cpu.processorCycles
note(c, 60, False, ms=900)
ev = nes_events(c, t0, nes1)
offs = [e for e in ev if e[1] == "off"]
bends = [e for e in ev if e[1] == "bend" and (not offs or e[0] < offs[0][0])]
check("the envelope's release fades as before (no fall-off timer)", c.v("nesFoT", 9)[2] == 0)
check("... and the note sags 5 semitones while it fades", bends and bends[-1][2] < bends[0][2] and bends[-1][2] < -400,
      [b[2] for b in bends][:12])
c.run_ms(3000)

# ---------------------------------------------------------------- the SID still does its own
send(c, 2, rdrop={"amount": 12, "time": 300})
note(c, 60, ms=200)
fh = c.raw[0xD400] | c.raw[0xD401] << 8
note(c, 60, False, ms=1000)
fb = c.raw[0xD400] | c.raw[0xD401] << 8
check("SID: unchanged (sags an octave)", abs(fh / fb - 2) < 0.1, (fh, fb))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
