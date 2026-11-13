#!/usr/bin/env python3
"""Fat Chip 64: MidiNES envelopes, startup settings, hard cuts. Since v0.19 the
NES follows each patch's main envelope (the SID's), so FAT decays to its
sustain and rings out with the SID too.
(The triangle release drop is off since v0.09; its code is kept for a future
mono bass sound.)"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS  # noqa: E402
C64.legacy_keys = True                       # (the keys before v0.22: sim.py translates)

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


P1, P2, TRI, NOI = 5, 6, 7, 8          # MidiNES channels (0-based), default block 6-10


def ms(cyc, t0):
    return round((cyc - t0) / CYCLES_PER_MS)


def on_ch(c, ch, since):
    """[(ms, kind, a, b)] for MIDI channel ch since cycle `since`."""
    out = []
    for cyc, s, a, b in c.midi(since=since):
        if s & 15 != ch:
            continue
        k = {0x90: "on", 0x80: "off", 0xB0: "cc", 0xE0: "bend"}.get(s & 0xF0, "?")
        if k == "on" and not b:
            k = "off"
        out.append((ms(cyc, since), k, a, b))
    return out


def bend_val(a, b):
    return ((b << 7) | a) - 8192


def pb_tri(n, x):
    return round(1710 * 0.5 ** ((n - 36) / 12) * (2 - 2 * 0.5 ** (x / 12)) / 4) * 4


c = C64()
c.run_ms(200)
start = [(s & 15, a, b) for _, s, a, b in c.midi() if (s & 0xF0) == 0xB0 and (s & 15) in (P1, P2, TRI, NOI, 9)]
check("startup: hardware envelope off (CC11 = 64) on pulses and noise",
      all((ch, 11, 64) in start for ch in (P1, P2, NOI)), start)
check("startup: sweep off and sweep period 0 on the pulses",
      all((ch, 13, 0) in start and (ch, 15, 0) in start for ch in (P1, P2)))

# ---------------------------------------------------------------- FAT: the SID's envelope
t0 = c.cpu.processorCycles
c.press("q", ms=400)
ev = on_ch(c, P1, t0)
check("FAT: full volume, a detune bend, the note (v0.15)", [e[1] for e in ev[:3]] == ["cc", "bend", "on"] and ev[0][3] == 120, ev)
vols = [e[3] for e in ev if e[1] == "cc"]
check("FAT: decays to sustain 12 (CC7 96) like the SID ($C9) and stays", vols[-1] == 96 and ev[-1][0] < 200, ev[-3:])
t1 = c.cpu.processorCycles
c.release("q", ms=1000)
rel = on_ch(c, P1, t1)
off_at = next((e[0] for e in rel if e[1] == "off"), None)
check("FAT: release fades 12 -> 0, then the note-off", [e[3] for e in rel if e[1] == "cc"][:2] == [88, 80] and rel[-1][1] == "off", rel[-3:])
check("FAT: ... in about 0.6 s (the SID: 750 ms from full)", off_at is not None and 500 <= off_at <= 800, off_at)
check("FAT: triangle note-off at once, no bends", [e[1] for e in on_ch(c, TRI, t1)] == ["off"])

# ---------------------------------------------------------------- PADS
c.tap("v", ms=60)
t0 = c.cpu.processorCycles
c.press("q", ms=1500)
ev = on_ch(c, P1, t0)
kinds = [e[1] for e in ev]
check("PADS: CC7 = 0 before the note-on", ev[0][1:] == ("cc", 7, 0) and kinds[1] == "on", ev[:3])
vols = [e[3] for e in ev if e[1] == "cc" and e[2] == 7]
peak_at = next((e[0] for e in ev if e[1] == "cc" and e[3] == 120), None)
check("PADS: attack climbs through the levels to 15 (CC7 120)", vols[1:16] == list(range(8, 128, 8)), vols)
check("PADS: attack takes about 0.5 s (the SID's $A)", peak_at is not None and 420 <= peak_at <= 600, peak_at)
check("PADS: sustain 15: stays at the top", vols[-1] == 120 and vols.count(120) == 1, vols[-3:])
check("PADS: pulse 2 gets the same envelope (C3 = pulse 2's note)",
      [e[3] for e in on_ch(c, P2, t0) if e[1] == "cc"][:3] == [0, 8, 16])
t1 = c.cpu.processorCycles
c.release("q", ms=2600)
rel = on_ch(c, P1, t1)
off_at = next((e[0] for e in rel if e[1] == "off"), None)
rvols = [e[3] for e in rel if e[1] == "cc"]
check("PADS: release fades 15 -> 0 before the note-off", rvols[:3] == [112, 104, 96] and rvols[-1] == 0 and
      rel[-1][1] == "off", rel[-4:])
check("PADS: release takes about 2.4 s (the SID's $B)", off_at is not None and 2000 <= off_at <= 2600, off_at)
tri = on_ch(c, TRI, t1)
check("PADS: the triangle (bass) just stops on release: note-off, no drop",
      [e[1] for e in tri] == ["off"] and tri[0][0] < 30, tri)

# re-press during the release cuts it and attacks again
c.press("q", ms=800)
c.release("q", ms=500)
t1 = c.cpu.processorCycles
c.press("q", ms=100)
ev = on_ch(c, P1, t1)
check("PADS: a new note during the release: off, CC7 0, on", [(e[1], e[3]) for e in ev[:3]] == [("off", 0), ("cc", 0), ("on", 100)], ev[:4])

# mute and panic cut at once
t1 = c.cpu.processorCycles
c.tap("m", ms=60)
ev = on_ch(c, P1, t1)
offs = [e for e in ev if e[1] == "off"]
check("PADS + mute: note-off at once (no fade)", offs and offs[0][0] < 30 and
      not [e for e in ev if e[1] == "cc" and e[0] > offs[0][0]], ev[:3])
c.tap("m", ms=200)
ev = [e for e in on_ch(c, P1, t1) if e[0] > offs[0][0]]
check("unmute: attacks again from 0", [(e[1], e[3]) for e in ev][:2] == [("cc", 0), ("on", 100)], ev[:4])
c.release("q", ms=300)
t1 = c.cpu.processorCycles
c.press("lshift", ms=10); c.tap("f7", ms=40); c.release("lshift", ms=10)
ev = on_ch(c, P1, t1)
check("PADS + panic during a release: note-off straight away", ev and ev[0][1] == "off" and ev[0][0] < 40, ev[:3])
c.run_ms(2500)
check("panic: no envelope left running", c.v("envPh", 2) == [0, 0] and c.v("triOn") == 0)

# back to FAT
c.press("q", ms=900)
t1 = c.cpu.processorCycles
c.tap("v", ms=60)
ev = on_ch(c, P1, t1)
check("FAT again: pulses back to full volume (CC7 127)", ("cc", 7, 127) in [e[1:] for e in ev], ev)
t1 = c.cpu.processorCycles
c.release("q", ms=1000)
check("FAT again: fades out, then the note-off", [e[1] for e in on_ch(c, P1, t1)][-1] == "off")

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
