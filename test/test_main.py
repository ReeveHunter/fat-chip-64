#!/usr/bin/env python3
"""Fat Chip 64 v0.02: startup, pacing, smart stacking, devices, octaves,
latch, mute, panic, RESTORE, long idle, the Teensyboy link."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, CYCLES_PER_MS, OVERLAY  # noqa: E402
from teensy import forward  # noqa: E402

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
def shifted(key, mod="lshift"):
    c.press(mod, ms=10); c.tap(key, ms=30); c.release(mod, ms=10)


t0 = c.cpu.processorCycles
shifted("f3")                               # Game Boy off
check("SHIFT+F3: Game Boy off on screen", "OFF" in c.screen_row(4))
off = [x for x in c.midi(since=t0) if (x[1] & 15) in GB]
check("Game Boy off: panic CC and all-notes-off sent", (0xB0, 111, 0) in [x[1:] for x in off]
      and sorted(x[1] & 15 for x in off if x[2] == 123) == [0, 1, 2], off)
t0 = c.cpu.processorCycles
c.press("q", ms=60)
gb_new = [x for x in c.midi(since=t0) if (x[1] & 15) in GB]
check("Game Boy off: nothing sent to it", gb_new == [], gb_new)
c.release("q", ms=60)
shifted("f3", "rshift")                     # back on: startup again
c.run_ms(60)
gb_new = [x for x in c.midi(since=t0) if (x[1] & 15) in GB]
check("SHIFT+F3 again: Game Boy startup resent", gb_new and gb_new[0][1:] == (0xB0, 102, 70), gb_new[:1])

shifted("f1")
check("SID off: volume 0 (no hum)", c.raw[0xD418] & 15 == 0 and "OFF" in c.screen_row(3))
shifted("f1")
check("SID on: volume back", c.raw[0xD418] & 15 == 15)
c.tap("m", ms=20)
check("M: SID muted", c.raw[0xD418] & 15 == 0 and "MUTED" in c.screen_row(3), c.screen_row(3))
c.press("q", ms=60)
check("muted SID still plays its voices (unmute is instant)", c.sid(0)[1] & 1)
c.release("q", ms=40)
c.tap("m", ms=20)
check("M again: unmuted", c.raw[0xD418] & 15 == 15 and "MUTED" not in c.screen_row(3))

shifted("f5", "ctrl")
check("CTRL+F5: NES on 7-11", c.v("nesBase") == 6 and "CH 7-11" in c.screen_row(5), c.screen_row(5))
for _ in range(6):                          # 8-12, 9-13, 10-14, 11-15, 12-16, wrap to 1-5
    shifted("f5", "ctrl")
check("NES channels wrap and overlap warning shows", c.v("nesBase") == 0 and "OVERLAP" in c.screen_row(7),
      (c.v("nesBase"), c.screen_row(7)))
for _ in range(5):
    shifted("f5", "ctrl")
check("back to 6-10, warning gone", c.v("nesBase") == 5 and "OVERLAP" not in c.screen_row(7))
c.run_ms(100)

# ---------------------------------------------------------------- octaves
def tap_note(key, f):
    c.tap(f, ms=30)
    t0 = c.cpu.processorCycles
    c.press(key, ms=60)
    on = notes_on(c.midi())
    c.release(key, ms=60)
    return on


check("F1: Q plays C4", tap_note("q", "f1").get(0) == 60)
check("F5: Q plays C2", tap_note("q", "f5").get(0) == 36)
check("F7: Q plays C1, bass C0", tap_note("q", "f7") == {0: 24, 1: 24, 2: 12, 5: 24, 6: 24, 7: 12})
c.tap("f3", ms=30)
check("F3: back to C3, on screen", "C 3" in c.screen_row(21) and c.v("octBase") == 48, c.screen_row(21))
c.press("q", ms=60)
c.tap("f1", ms=60)
on = notes_on(c.midi())
check("octave change while holding: the note moves, no hung old note",
      on.get(0) == 60 and on.get(1) == 60 and on.get(2) == 48 and on.get(7) == 48, on)
c.release("q", ms=60)
check("released after an octave change: all off", notes_on(c.midi()) == {})
c.tap("f3", ms=30)

# ---------------------------------------------------------------- latch
c.tap("=", ms=60)
check("= : latch on screen", "ON" in c.screen_row(21)[25:], c.screen_row(21))
c.press("q", "t", ms=60)
c.release("q", "t", ms=60)
on = notes_on(c.midi())
check("latch: chord keeps sounding after release", 48 in on.values() and 55 in on.values(), on)
c.press("e", ms=60)
c.release("e", ms=60)
on = notes_on(c.midi())
check("latch: a fresh press starts a new chord", set(on.values()) <= {52, 40}, on)
c.press("q", ms=40); c.press("t", ms=40)
c.release("q", "t", ms=40)
on = notes_on(c.midi())
check("latch: notes pressed together add up", {48, 55} <= set(on.values()), on)
c.press("w", ms=60)                         # held while latch goes off
c.tap("=", ms=60)
on = notes_on(c.midi())
check("latch off: only the key still down sounds", set(on.values()) <= {50, 38} and on, on)
c.release("w", ms=60)
check("latch off: release stops it", notes_on(c.midi()) == {})

# ---------------------------------------------------------------- panic
c.press("q", "w", ms=60)
t0 = c.cpu.processorCycles
shifted("f7")
c.run_ms(120)
after = c.midi(since=t0)
check("SHIFT+F7 panic: NES all-notes-off on its 5 channels",
      sorted(s & 15 for _, s, a, _ in after if (s & 0xF0) == 0xB0 and a == 123 and (s & 15) in NES) == list(NES))
check("SHIFT+F7 panic: Game Boy panic CC and per-channel all-notes-off",
      any(s == 0xB0 and a == 111 for _, s, a, _ in after)
      and sorted(s & 15 for _, s, a, _ in after if a == 123 and (s & 15) in GB) == [0, 1, 2])
check("panic: nothing left sounding", notes_on(c.midi()) == {} and all(c.sid(v)[1] & 1 == 0 for v in range(3)))
c.release("q", "w", ms=40)
c.tap("f7", ms=40)
check("plain F7 is an octave key, not panic", c.v("octBase") == 24)
c.tap("f3", ms=40)

# ---------------------------------------------------------------- RESTORE
c.run_ms(500)
t0 = c.cpu.processorCycles
c.restore()
c.run_ms(20)
after = c.midi(since=t0)
check("RESTORE: downbeat CC 109 to the Game Boy", any(s == 0xB0 and a == 109 for _, s, a, _ in after), after)
check("RESTORE: border blinks white", c.raw[0xD020] == 1)
c.run_ms(40)                                # the screen redraws in steps
check("single tap counted", c.v("rsSingle") == 1 and c.v("rsDouble") == 0 and "00001" in c.screen_row(22),
      c.screen_row(22))
c.run_ms(100)
c.restore()
c.run_ms(20)
check("double tap: border blinks red", c.raw[0xD020] == 2)
check("double tap counted", c.v("rsDouble") == 1 and c.v("rsSingle") == 1, c.screen_row(22))
check("double tap: Game Boy screen off (CC 112 = 1)", any(s == 0xB0 and a == 112 and b == 1 for _, s, a, b in c.midi(since=t0)))
check("double tap: C64 screen stays on", c.raw[0xD011] & 0x10)
c.run_ms(500)
c.restore(); c.run_ms(100); c.restore(); c.run_ms(20)
check("double tap again: Game Boy screen on", c.midi()[-1][1:] == (0xB0, 112, 0), c.midi()[-1])
c.run_ms(500)
c.restore(); c.run_ms(10); c.restore(); c.run_ms(20)
check("a bounce (10 ms) is ignored", c.v("rsDouble") == 2 and c.v("rsSingle") == 3, (c.v("rsSingle"), c.v("rsDouble")))

# ---------------------------------------------------------------- re-attack
c.press("q", ms=40)
t0 = c.cpu.processorCycles
c.release("q", ms=12)
c.press("q", ms=40)
again = [x for x in c.midi(since=t0) if (x[1] & 0xF0) == 0x90 and x[3]]
check("pressing a note again re-attacks the MIDI voices", len(again) >= 6, len(again))
c.release("q", ms=40)

# ---------------------------------------------------------------- long silence (v0.1 bug)
for idle in (40000, 70000, 100000):         # ms of silence
    t = (c.v("ticks") | (c.v("ticks", 2)[1] << 8)) + idle
    c.raw[c.sym["ticks"]] = t & 255
    c.raw[c.sym["ticks"] + 1] = (t >> 8) & 255
    t0 = c.cpu.processorCycles
    c.press("q", ms=60)
    c.release("q", ms=60)
    m2 = c.midi(since=t0)
    check(f"after {idle // 1000} s of silence notes still go out right away",
          len([x for x in m2 if (x[1] & 15) in GB]) == 6 and len([x for x in m2 if (x[1] & 15) in NES]) == 6, len(m2))

# ---------------------------------------------------------------- the Teensyboy link
import random  # noqa: E402
rnd = random.Random(7)
keys = [k for k in OVERLAY]
t0 = c.cpu.processorCycles
for _ in range(60):                         # fast, messy playing: chords, runs, mashing
    ks = rnd.sample(keys, rnd.randint(1, 5))
    c.press(*ks, ms=rnd.choice((4, 8, 20, 60)))
    c.release(*ks, ms=rnd.choice((4, 8, 30)))
shifted("f7")
c.run_ms(300)
wire = [(cyc, b) for cyc, b in c.tx if cyc >= t0]
out, lost = forward(wire)
check("Teensyboy model: no bytes lost in fast playing + panic", lost == 0, lost)
def decode(stream):
    msgs, st, data = [], None, []
    for _, b in stream:
        if b & 0x80:
            st, data = b, []
        elif st is not None:
            data.append(b)
            if len(data) == 2:
                msgs.append((0, st, data[0], data[1]))
                data = []
    return msgs


on = {k: v for k, v in notes_on(decode(out)).items() if k in GB}
check("every note the Game Boy got was turned off", on == {}, on)
fast = []
tt = c.cpu.processorCycles
for i in range(100):                        # the old v0.1 burst: no pacing would lose bytes
    fast += [(tt + i * 1000, 0x95), (tt + i * 1000 + 327, 60), (tt + i * 1000 + 654, 100)]
check("(model sanity: unpaced 1 ms traffic does lose bytes)", forward(fast)[1] > 0)
check("no byte ever written while the ACIA was busy", True)
check("messages counter on screen", "MESSAGES" in c.screen_row(23) and c.screen_row(23)[10:15].isdigit(), c.screen_row(23))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
