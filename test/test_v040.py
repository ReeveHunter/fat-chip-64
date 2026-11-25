#!/usr/bin/env python3
"""Fat Chip 64 v0.40: the keys on Reeve's Fat Chip Shortcuts sheet. Plain keys
play and pick; SHIFT the split / lead; C= the effects (on / off, and the last
one's settings); RUN/STOP the beats and tempo; CTRL the setup. <- undoes a
patch change; the dice name the patch RANDOM PATCH; the help page in colours."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def mod(c, m, *keys, ms=40):
    c._raw_press(m, ms=30)
    for k in keys:
        c._raw_tap(k, ms=ms)
    c._raw_release(m, ms=60)


def name(c):
    a = c.sym["patchName"]
    return bytes(c.raw[a:a + 16]).decode("ascii", "replace").rstrip()


def held(c):
    return c.v("heldList", 8)[:c.v("heldCount")]


def fx_on(c, i):
    return c.v("fxFocus") == i + 1


c = C64(channels=None)
c.fkeys_036 = False
c.keys_039 = False
c.run_ms(400)
check("header V0.65", "V0.65" in c.screen_row(0), c.screen_row(0))
S = c.sym

# ---------------------------------------------------------------- plain keys
b0, s0, m0 = c.v("curBank"), c.v("curSlot"), c.v("soundMode")
c._raw_tap(";", ms=60)
check("; : the next patch", (c.v("curBank"), c.v("curSlot")) != (b0, s0) and c.v("soundMode") != m0,
      (c.v("curBank"), c.v("curSlot")))
c._raw_tap(":", ms=60)
check(": : back to the one before", (c.v("curBank"), c.v("curSlot"), c.v("soundMode")) == (b0, s0, m0))
c._raw_tap(":", ms=60)
check(": from the first: round to the last filled slot (bank 5)", c.v("curBank") == 4, (c.v("curBank"), c.v("curSlot")))
c._raw_tap(";", ms=60)

n0 = name(c)
c._raw_tap("/", ms=100)
check("/ : the dice; the patch is called RANDOM PATCH", name(c) == "RANDOM PATCH", name(c))
c._raw_tap("left", ms=100)
check("<- : back to the patch before", name(c) == n0, name(c))
c._raw_tap("left", ms=100)
check("<- again: forward to the roll", name(c) == "RANDOM PATCH", name(c))
c._raw_tap("left", ms=100)
c._raw_tap("x", ms=60)
c._raw_tap("left", ms=100)
check("<- after picking a patch: the patch before it", name(c) == n0 and c.v("soundMode") == m0, (name(c), c.v("soundMode")))

c._raw_tap("m", ms=40)
check("M: mute", c.v("sidMute") == 1)
c._raw_tap("m", ms=40)
sp = c.v("spice")
c._raw_tap("n", ms=40)
check("N: the chord's size (extensions)", c.v("spice") == (sp + 1) % 5, c.v("spice"))

c.set("monoMode", 0)
c.set("playMode", 0)
seen = []
for _ in range(3):
    c._raw_tap("f7", ms=60)
    seen.append((c.v("playMode"), c.v("monoMode")))
check("F7 (v0.47): from POLY, SMART CHORD, MONO, POLY", seen == [(1, 0), (0, 1), (0, 0)], seen)
mod(c, "ctrl", "crsrdown")
check("CTRL + CRSR: DRONE", c.v("playMode") == 2)
mod(c, "ctrl", "crsrdown")
check("... again: back to PLAY (POLY)", c.v("playMode") == 0)

bm = c.v("beatMs") | c.v("beatMs", 2)[1] << 8
c._raw_press(",", ms=80)
bn = c.v("beatMs") | c.v("beatMs", 2)[1] << 8
c._raw_release(",", ms=80)
be = c.v("beatMs") | c.v("beatMs", 2)[1] << 8
check(", held: a nudge (the beat ~3% longer), let go: as it was", bn > bm * 1.02 and be == bm, (bm, bn, be))

# ---------------------------------------------------------------- SHIFT
mod(c, "lshift", ".", ".")
check("SHIFT + . twice: TRANSPOSE +2 (row 13: TRANS +2)", c.v("transp") == 2 and "TRANS +2" in c.screen_row(13), c.screen_row(13))
c.press("q", ms=100)
check("... the lowest key plays D3 (50)", held(c) == [50], held(c))
c.release("q", ms=100)
mod(c, "lshift", ",", ",")
check("SHIFT + , twice: back to 0 (nothing shown)", c.v("transp") == 0 and "TRANS" not in c.screen_row(13))

mod(c, "lshift", "k")
check("SHIFT + K: waiting for the split point (row 3: ?)", c.v("spArm") == 1 and "?" in c.screen_row(3), c.screen_row(3))
c.press("e", ms=80)
c.release("e", ms=80)
check("... E: the split there, SPLIT KEY, nothing played", c.v("splitKey") == 4 and c.v("clMode") == 1 and c.v("spArm") == 0
      and held(c) == [], (c.v("splitKey"), c.v("clMode"), held(c)))
mod(c, "lshift", "f7")                                       # (v0.43: F7 the cycle, F5 on / off)
check("SHIFT + F7: SPLIT's next mode (BASS)", c.v("clMode") == 2)
mod(c, "lshift", "f5")
check("SHIFT + F5: SPLIT off", c.v("clMode") == 0)
mod(c, "lshift", "f5")
check("SHIFT + F5: on again (BASS)", c.v("clMode") == 2)
mod(c, "lshift", "f5")
lp = c.v("leadSlot"), c.v("leadBank")
mod(c, "lshift", ";")
check("SHIFT + ; : the lead's next patch", (c.v("leadSlot"), c.v("leadBank")) != lp)

# ---------------------------------------------------------------- RUN/STOP
bpm = c.v("bpm")
mod(c, "runstop", ".")
check("RUN/STOP + . : tempo +1", c.v("bpm") == bpm + 1, (bpm, c.v("bpm")))
mod(c, "runstop", ",")
check("RUN/STOP held as a modifier: the beat didn't start", c.v("beatRun") == 0)
mod(c, "runstop", "s")
check("RUN/STOP + S: beat bank 2 (beat 6)", c.v("beatSel") == 5 and c.v("beatBank") == 1, c.v("beatSel"))
mod(c, "runstop", "a", "c")
check("RUN/STOP + A, C: beat 3", c.v("beatSel") == 2, c.v("beatSel"))
mod(c, "runstop", ":")
check("RUN/STOP + : : the beat before", c.v("beatSel") == 1)
c._raw_press("runstop", ms=30)
c._raw_press("space", ms=40)
check("RUN/STOP + SPACE held: FILL", c.v("spaceDown") == 1 and c.v("spaceHeld") == 13, c.v("spaceHeld"))
c._raw_release("space", ms=40)
c._raw_release("runstop", ms=60)

# ---------------------------------------------------------------- C=
mod(c, "cbm", "v")
check("C= + V: VIBRATO on, the one C= works on (row 14)", fx_on(c, S["FXI_VIBRATO"]) and "VIBRATO" in c.screen_row(14), c.screen_row(14))
check("... row 14: its first setting (DEPTH)", "DEPTH" in c.screen_row(14), c.screen_row(14))
d0 = c.screen_row(14)[29:].strip()
mod(c, "cbm", "crsrright")                                   # (v0.45: was C= + ;)
c.run_ms(250)                                                # (v0.64: the Game Boy's messages carry their status bytes, so its sound takes a little longer and the row redraws after)
check("C= + CRSR RIGHT: its setting a step up", c.screen_row(14)[29:].strip() != d0, (d0, c.screen_row(14)))
mod(c, "cbm", ".")
c.run_ms(250)
check("C= + . : faster (row 14: RATE)", "RATE" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "crsrdown")                                    # (v0.45: was C= + RETURN)
c.run_ms(100)                                                # (the row redrawn)
check("C= + CRSR DOWN: the next setting (DELAY)", "DELAY" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "v")
check("C= + V again: off (row 14 dark grey)", c.raw[0xD800 + 14 * 40 + 4] & 15 == 11, c.raw[0xD800 + 14 * 40 + 4] & 15)
c._raw_tap("left", ms=100)
check("<- : the effect back on", c.raw[0xD800 + 14 * 40 + 4] & 15 == 13)

p_atk = c.v("efP0", 3)[2]
mod(c, "cbm", "z")
a1 = c.v("livePatch", 128)
check("C= + Z: ENVELOPE ATTACK (row 14)", "ATTACK" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "z")
a2 = c.v("livePatch", 128)
check("C= + Z again: the attack the other way", a1 != a2)

mod(c, "cbm", "c")
check("C= + C: TREMOLO", fx_on(c, S["FXI_TREMOLO"]), c.v("fxFocus"))
mod(c, "cbm", "l")
c.run_ms(100)                             # (the row redrawn)
check("C= + L: TREMOLO SYNC on (1/4)", "SYNC" in c.screen_row(14) and "1/4" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "l")
c.run_ms(100)
check("C= + L again: FREE", "FREE" in c.screen_row(14), c.screen_row(14))
mod(c, "cbm", "c")

mod(c, "cbm", "a")
check("C= + A: the arp on", c.v("arpMode") != 0)
t0 = c.v("arpMode")
mod(c, "cbm", "f7")
check("C= + F7: the arp's type", c.v("arpMode") != t0, (t0, c.v("arpMode")))
c.set("arpOct", 0)
c.set("arpLen", 3)
mod(c, "cbm", "f1")                                          # (v0.43: F1 up, as everywhere)
check("C= + F1: arp octave up", c.v("arpOct") == 1, c.v("arpOct"))
mod(c, "cbm", "f3")
check("C= + F3: down", c.v("arpOct") == 0)
mod(c, "cbm", "f5")
check("C= + F5: arp FREE", c.v("arpLen") == 5)
mod(c, "cbm", "f5")
check("C= + F5: synced again (1/16)", c.v("arpLen") == 3, c.v("arpLen"))
pat = c.v("arpPat")
mod(c, "cbm", "crsrright")
check("C= + CRSR RIGHT with the arp: its pattern", c.v("arpPat") == (pat + 1) % 5)
mod(c, "cbm", "a")
check("C= + A: off", c.v("arpMode") == 0)
c._raw_press("cbm", ms=30)
c._raw_press("space", ms=40)
check("C= + SPACE held: VINYL", c.v("spaceHeld") == 7)
c._raw_release("space", ms=40)
c._raw_release("cbm", ms=300)

# ---------------------------------------------------------------- CTRL
mod(c, "ctrl", "a")
check("CTRL + A: the SID off", c.v("devOn", 3)[0] == 0, c.v("devOn", 3))
mod(c, "ctrl", "a")
ft = c.v("fineTune")
mod(c, "ctrl", "j")
check("CTRL + J: fine tune +1", c.v("fineTune") == ft + 1)
mod(c, "ctrl", "h")
ls = c.v("latchStyle")
mod(c, "ctrl", "l")
check("CTRL + L: the latch style", c.v("latchStyle") == (ls + 1) % 3)
sa = c.v("spaceAct")
mod(c, "ctrl", ".")
check("CTRL + . : SPACE's next FX", c.v("spaceAct") == sa + 1)
mod(c, "ctrl", ",")
mod(c, "ctrl", "f1")
check("CTRL + F1: MIDI in octave up", c.v("midiOct") == 1)
mod(c, "ctrl", "f3")

# ---------------------------------------------------------------- the menu
c._raw_tap("return", ms=80)
c._raw_tap("return", ms=80)                          # (HELP: THE KEYS, the first line)
rows = [c.screen_row(r) for r in range(25)]
cols = [c.raw[0xD800 + r * 40 + 2] & 15 for r in range(25)]
r_sh = next(r for r in range(25) if rows[r].startswith(" SHIFT"))
r_cb = next(r for r in range(25) if rows[r].startswith(" C="))
r_st = next(r for r in range(25) if rows[r].startswith(" STOP"))
r_ct = next(r for r in range(25) if rows[r].startswith(" CTRL"))
check("help: the plain keys white, SHIFT orange, C= green, RUN/STOP light blue, CTRL light red",
      (cols[2], cols[r_sh], cols[r_cb], cols[r_st], cols[r_ct]) == (1, 8, 5, 14, 10), cols)
c._raw_press("lshift", ms=8); c._raw_tap("return", ms=60); c._raw_release("lshift", ms=60)
check("back: the menu's own colour again", c.raw[0xD800 + r_sh * 40 + 2] & 15 == 13)
for _ in range(40):
    if any(c.screen_row(r).startswith("> DEVICES") for r in range(25)):
        break
    c._raw_tap("crsrdown", ms=25)
c._raw_tap("return", ms=60)
for _ in range(40):
    if any(c.screen_row(r).startswith("> GAME BOY CHANNELS") for r in range(25)):
        break
    c._raw_tap("crsrdown", ms=25)
g0 = c.v("gbBase")
c._raw_tap("crsrright", ms=150)
check("DEVICES: GAME BOY CHANNELS, CRSR RIGHT: the next block", c.v("gbBase") == (g0 + 1) % 12, (g0, c.v("gbBase")))
c._raw_press("lshift", ms=8); c._raw_tap("crsrright", ms=150); c._raw_release("lshift", ms=60)
check("... SHIFT + CRSR RIGHT: back", c.v("gbBase") == g0, c.v("gbBase"))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
