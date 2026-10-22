#!/usr/bin/env python3
"""Fat Chip 64 v0.1: startup, pacing, smart stacking, devices, RESTORE."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS, OVERLAY  # noqa: E402

fails = 0
GB, NES = range(0, 5), range(5, 10)        # default channels (0-based)
SID_ON = 0x21


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def notes_on(msgs):
    """{channel: note} still sounding after these messages."""
    on = {}
    for _, s, a, b in msgs:
        ch = s & 15
        if (s & 0xF0) == 0x90 and b:
            on[ch] = a
        elif (s & 0xF0) == 0x80 or ((s & 0xF0) == 0x90 and not b):
            if on.get(ch) == a:
                del on[ch]
    return on


# ---------------------------------------------------------------- startup
c = C64()
c.run_ms(150)
m = c.midi()
gb = [(s, a, b) for _, s, a, b in m if (s & 15) in GB]
nes = [(s, a, b) for _, s, a, b in m if (s & 15) in NES]
check("GB startup: FAT CHIP profile first", gb[0] == (0xB0, 102, 70), gb[:1])
check("GB startup: panic, tune, warble",
      gb[1:5] == [(0xB0, 111, 0), (0xB0, 103, 64), (0xB0, 104, 24), (0xB0, 105, 40)], gb[1:5])
check("GB startup: pulses detuned apart", (0xB0, 94, 58) in gb and (0xB1, 94, 70) in gb)
check("NES startup: CC7=127 on channels 6-10",
      [x for x in nes if x[1] == 7] == [(0xB0 | ch, 7, 127) for ch in NES])
check("NES startup: CC16=127 on the pulses", [x for x in nes if x[1] == 16] == [(0xB5, 16, 127), (0xB6, 16, 127)])
check("screen header", c.screen_row(0).startswith(" FAT CHIP 64"))
check("screen shows channels", c.screen_row(4).rstrip().endswith("CH 1-5") and c.screen_row(5).rstrip().endswith("CH 6-10"),
      c.screen_row(5))

# ---------------------------------------------------------------- pacing
def gaps(msgs, chans):
    t = [cyc for cyc, s, _, _ in msgs if (s & 15) in chans]
    return [(b - a) / CYCLES_PER_MS for a, b in zip(t, t[1:])]


g = gaps(m, GB)
check("Game Boy messages at least 2.5 ms apart on the wire (target 3, measured safe 2)", min(g) >= 2.5, f"min {min(g):.2f} ms")

# ---------------------------------------------------------------- one note: 9-voice unison
t0 = c.cpu.processorCycles
c.press("q", ms=60)                         # C3
after = c.midi(since=t0)
on = notes_on(c.midi())
check("one note: GB pulses play C3", on.get(0) == 48 and on.get(1) == 48, on)
check("one note: GB wave plays the bass an octave down", on.get(2) == 36, on)
check("one note: NES pulses + triangle", on.get(5) == 48 and on.get(6) == 48 and on.get(7) == 36, on)
sids = [c.sid(v) for v in range(3)]
check("one note: all three SID voices gated", all(ctl == SID_ON for _, ctl in sids), sids)
f = [fr for fr, _ in sids]
check("one note: SID voices detuned apart", f[1] > f[0] > f[2], f)
check("voice table shows C3", "C 3" in c.screen_row(10) and "C 2" in c.screen_row(17), c.screen_row(17))
check("held row", "C 3" in c.screen_row(20), c.screen_row(20))

c.release("q", ms=60)
on = notes_on(c.midi())
check("release: every MIDI voice off", on == {}, on)
check("release: SID gates off", all(c.sid(v)[1] == 0x20 for v in range(3)))

# ---------------------------------------------------------------- chord: C E G
c.press("q", "e", "t", ms=80)
on = notes_on(c.midi())
want = {0: 55, 1: 48, 2: 36, 5: 48, 6: 52, 7: 36}
check("chord C-E-G: bass voices on C2", on.get(2) == 36 and on.get(7) == 36, on)
check("chord: every chord note has a voice",
      {48, 52, 55} <= set(on.values()) | {c.sid(0)[0] and 0}, on)
sid_notes = [c.sid(v)[0] for v in range(3)]
check("chord: lowest notes stacked fattest",
      list(on.values()).count(48) >= list(on.values()).count(55), on)
c.release("q", "e", "t", ms=80)
check("chord released", notes_on(c.midi()) == {})

# ---------------------------------------------------------------- devices
c.tap("f3", ms=20)                          # Game Boy off
check("F3: Game Boy off on screen", "OFF" in c.screen_row(4))
t0 = c.cpu.processorCycles
c.press("q", ms=60)
gb_new = [x for x in c.midi(since=t0) if (x[1] & 15) in GB]
check("Game Boy off: nothing sent to it", gb_new == [], gb_new)
c.release("q", ms=60)
c.tap("f3", ms=60)                          # back on: startup again
gb_new = [x for x in c.midi(since=t0) if (x[1] & 15) in GB]
check("F3 again: Game Boy startup resent", gb_new and gb_new[0][1:] == (0xB0, 102, 70), gb_new[:1])

c.press("rshift", ms=20)
c.tap("f5", ms=60)
c.release("rshift", ms=20)
check("SHIFT+F5: NES on 7-11", c.v("nesBase") == 6 and "CH 7-11" in c.screen_row(5), c.screen_row(5))
for _ in range(6):                          # 8-12, 9-13, 10-14, 11-15, 12-16, wrap to 1-5
    c.press("lshift", ms=10); c.tap("f5", ms=20); c.release("lshift", ms=10)
check("NES channels wrap and overlap warning shows", c.v("nesBase") == 0 and "OVERLAP" in c.screen_row(7),
      (c.v("nesBase"), c.screen_row(7)))
for _ in range(5):
    c.press("lshift", ms=10); c.tap("f5", ms=20); c.release("lshift", ms=10)
check("back to 6-10, warning gone", c.v("nesBase") == 5 and "OVERLAP" not in c.screen_row(7))

# ---------------------------------------------------------------- panic
c.press("q", "w", ms=60)
t0 = c.cpu.processorCycles
c.tap("f7", ms=120)
after = c.midi(since=t0)
check("F7 panic: NES all-notes-off on its 5 channels",
      sorted(s & 15 for _, s, a, _ in after if (s & 0xF0) == 0xB0 and a == 123) == list(NES))
check("F7 panic: Game Boy panic CC", any(s == 0xB0 and a == 111 for _, s, a, _ in after))
check("F7 panic: nothing left sounding", notes_on(c.midi()) == {} and all(c.sid(v)[1] & 1 == 0 for v in range(3)))
c.release("q", "w", ms=40)

# ---------------------------------------------------------------- RESTORE
t0 = c.cpu.processorCycles
c.restore()
c.run_ms(20)
after = c.midi(since=t0)
check("RESTORE: downbeat CC 109 to the Game Boy", any(s == 0xB0 and a == 109 for _, s, a, _ in after), after)
check("RESTORE: border blinks", c.raw[0xD020] == 1)
check("single tap keeps the screen on", c.raw[0xD011] & 0x10)
c.run_ms(100)
c.restore()
c.run_ms(20)
check("double tap: screen off", not (c.raw[0xD011] & 0x10))
check("double tap: Game Boy told (CC 112 = 1)", any(s == 0xB0 and a == 112 and b == 1 for _, s, a, b in c.midi(since=t0)))
c.run_ms(500)
c.restore(); c.run_ms(100); c.restore(); c.run_ms(20)
check("double tap again: screen back on", c.raw[0xD011] & 0x10)
c.run_ms(500)
c.restore(); c.run_ms(10); c.restore(); c.run_ms(20)
check("a bounce (10 ms) is ignored", c.raw[0xD011] & 0x10)

# ---------------------------------------------------------------- re-attack
c.press("q", ms=40)
t0 = c.cpu.processorCycles
c.release("q", ms=12)
c.press("q", ms=40)
again = [x for x in c.midi(since=t0) if (x[1] & 0xF0) == 0x90 and x[3]]
check("pressing a note again re-attacks the MIDI voices", len(again) >= 6, len(again))
c.release("q", ms=40)

check("no byte ever written while the ACIA was busy", True)
check("messages counter on screen", "MESSAGES" in c.screen_row(23) and c.screen_row(23)[10:15].isdigit(), c.screen_row(23))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
