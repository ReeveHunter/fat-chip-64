#!/usr/bin/env python3
"""Fat Chip 64 v0.24: the new menu (the chips on top, PATCH pages that edit
the live patch, PLAYING, DEVICES and a page per device in use), the dice
(global and on one setting), the SHS-10's 25 voice buttons, the DH-100's
breath and buttons, Synthcart tempo nudges, steps and trim."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64  # noqa: E402

fails = 0
FLD = {"sndAD": 6, "sndSR": 7, "gbAtk": 32, "gbLDest": 44}
A_VIB, A_GLIDE = 3, 8


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


def rows(c):
    return [c.screen_row(r) for r in range(25)]


def sel(c, label):
    """CRSR DOWN until the cursor is on the line starting with label."""
    for _ in range(30):
        if any(r.startswith("> " + label) for r in rows(c)):
            return True
        c.tap("crsrdown", ms=25)
    return False


def row_of(c, label):
    return next((r for r in rows(c) if r[2:].startswith(label)), "")


def shift(c, key, ms=40):
    c._raw_press("lshift", ms=8)
    c._raw_tap(key, ms=ms)
    c._raw_release("lshift", ms=8)


def back(c, n=1):
    c._raw_press("lshift", ms=8)
    for _ in range(n):
        c._raw_tap("return", ms=50)
    c._raw_release("lshift", ms=40)


def patch(c):
    return c.v("livePatch", 82)


def name(c):
    n = c.sym["patchName"] - c.sym["livePatch"]
    return bytes(c.v("livePatch", 128)[n:n + 16]).decode("latin-1")


c = C64(channels=None)
c.run_ms(400)
check("header V0.35", "V0.35" in c.screen_row(0), c.screen_row(0))

# ---------------------------------------------------------------- the main page
c.tap("return", ms=80)
r = rows(c)
check("main page: HELP first, then SID / GAME BOY / MIDINES, all ON", all("ON" in r[i][23:] for i in (4, 5, 6))
      and r[2].startswith("> HELP") and r[4][2:].startswith("SID"), r[2:7])
check("... the SHS-10's page (in use); the DH-100 and Synthcart hidden",
      r[13][2:].startswith("YAMAHA SHS-10") and "CASIO" not in "".join(r) and "SYNTHCART" not in "".join(r))
c.tap("f3", ms=30); c.tap("f3", ms=30)
c.tap("f7", ms=150)
check("F3 x2 (past the gap): GAME BOY; F7 turns it off", c.v("devOn", 3) == [1, 0, 1] and "OFF" in c.screen_row(5), c.v("devOn", 3))
c.tap("f5", ms=300)
check("... F5: on again", c.v("devOn", 3) == [1, 1, 1] and "ON" in c.screen_row(5))
c.tap("f1", ms=30)
check("F1: up a line (SID)", c.screen_row(4).startswith("> SID"))
c.tap("f1", ms=30)
c.tap("return", ms=60)
r = rows(c)
check("HELP: the keys, as text (no cursor, F keys stay put)", "HELP" in r[0] and r[2].startswith(" ASDFG BANK")
      and not any(x.startswith(">") for x in r), r[2:4])
c.tap("f3", ms=30); c.tap("f7", ms=30)
check("... F3 / F7 do nothing there", not any(x.startswith(">") for x in rows(c)) and c.v("menuPage") == 1)
back(c)
check("SHIFT+RETURN: back, on HELP", c.screen_row(2).startswith("> HELP"))

# ---------------------------------------------------------------- DEVICES
check("DEVICES", sel(c, "DEVICES"))
c.tap("return", ms=60)
check("DEVICES page: SHS-10 IN USE, the others NOT USED", "IN USE" in row_of(c, "YAMAHA") and "NOT USED" in row_of(c, "CASIO")
      and "NOT USED" in row_of(c, "ATARI"), rows(c)[2:7])
sel(c, "CASIO")
c.tap("crsrright", ms=60)
sel(c, "ATARI")
c.tap("crsrright", ms=60)
sel(c, "YAMAHA")
c.tap("crsrright", ms=60)
check("all three changed", c.v("useShs") == 0 and c.v("useDh") == 1 and c.v("useSc") == 1)
back(c)
r = rows(c)
check("main page: the DH-100 and Synthcart pages, not the SHS-10's (the lines move up)",
      r[13][2:].startswith("CASIO DH-100") and r[14][2:].startswith("ATARI SYNTHCART") and "YAMAHA" not in "".join(r), r[10:13])
check("... the cursor back on DEVICES", c.screen_row(11).startswith("> DEVICES"))
c.tap("crsrdown", ms=30); c.tap("crsrdown", ms=30); c.tap("crsrdown", ms=30)
check("CRSR DOWN skips the gaps and hidden lines: wraps from SYNTHCART to HELP", c.screen_row(2).startswith("> HELP"), c.screen_row(2))
check("SHS-10 not in use: no keytar tempo, start / stop or drums", c.v("syncTempo") == 1 and c.v("syncStart") == 1
      and c.v("syncDrums") == 0, (c.v("syncTempo"), c.v("syncStart")))
back(c)

# ---------------------------------------------------------------- the SHS-10
c.midi_in(0xC0, 5, ms=300)
check("SHS-10 not in use: its voice buttons ignored", c.v("soundMode") == 0)
c.set("useShs", 1); c.set("useDh", 0); c.set("useSc", 0)
c.tap("return", ms=60)
sel(c, "DEVICES"); c.tap("return", ms=60); sel(c, "YAMAHA"); c.tap("crsrright", ms=40); c.tap("crsrright", ms=40)
back(c, 2)
check("(DEVICES: only the SHS-10, as at power on)", c.v("syncTempo") == 0 and c.v("syncStart") == 0 and c.v("useDh") == 0)
for voice, want in ((5, "PADS  1"), (11, "LEADS 2"), (24, "FX    5"), (22, "FX    3")):
    c.midi_in(0xC0, voice, ms=300)
    check(f"voice button {voice + 1}: bank slot {want}", c.screen_row(2).startswith(want), c.screen_row(2))
n0 = c.v("soundMode")
c.midi_in(0xC0, 3, ms=300)
check("voice button 4: an empty slot (FAT 4) does nothing", c.v("soundMode") == n0)
c.midi_in(0xC0, 0, ms=300)

# ---------------------------------------------------------------- the PATCH page
c.tap("return", ms=60)
sel(c, "PATCH")
c.tap("return", ms=80)
r = rows(c)
check("PATCH page: the patch's name under the title", r[1].startswith(" FAT"), r[1])
check("... MONO, FAT BASS, then the effects", r[3][2:].startswith("MONO") and r[4][2:].startswith("FAT BASS"), r[3:6])
check("... VIBRATO OFF (FAT has none)", "OFF" in row_of(c, "VIBRATO"), row_of(c, "VIBRATO"))
sel(c, "VIBRATO")
c.tap("crsrright", ms=150)
check("CRSR RIGHT: VIBRATO ON: the SID vibrato, the Game Boy LFO to pitch, the name marked",
      "ON" in row_of(c, "VIBRATO") and c.v("vibDepth") > 0 and patch(c)[FLD["gbLDest"]] == 0 and name(c).endswith("*"),
      (c.v("vibDepth"), name(c)))
c.tap("return", ms=80)
check("RETURN: VIBRATO's page", "VIBRATO" in c.screen_row(0) and c.screen_row(3).startswith(">"), rows(c)[0:5])
d0 = c.v("vibDepth")
v0 = c.screen_row(3)[23:].strip()
c.tap("crsrright", ms=100)
check("CRSR RIGHT on its first setting: the next step, heard at once", c.screen_row(3)[23:].strip() != v0
      and c.v("vibDepth") != d0, (v0, c.screen_row(3)[23:].strip(), d0, c.v("vibDepth")))
p0 = patch(c)
shift(c, "/", ms=100)
p1 = patch(c)
diff = [i for i in range(82) if p0[i] != p1[i]]
check("SHIFT + / on a setting: rolls only it (a byte or two), undo armed", len(diff) <= 3 and c.v("undoOk") == 1, diff)
c._raw_press("cbm", ms=8); c._raw_tap("/", ms=100); c._raw_release("cbm", ms=8)
check("C= + /: undone", patch(c) == p0)
back(c)
check("SHIFT+RETURN: back on the PATCH page, on VIBRATO", c.screen_row(0).startswith(" PATCH") and
      any(x.startswith("> VIBRATO") for x in rows(c)))
c.tap("crsrright", ms=150)
check("VIBRATO OFF again: no vibrato", "OFF" in row_of(c, "VIBRATO") and c.v("vibDepth") == 0)

# the envelope
sel(c, "ENVELOPE")
c.tap("crsrright", ms=80)
check("ENVELOPE (always on): CRSR RIGHT opens it", "ENVELOPE" in c.screen_row(0), c.screen_row(0))
a0 = patch(c)[FLD["sndAD"]] >> 4
for _ in range(9):
    c.tap("crsrright", ms=40)
p = patch(c)
check("ATTACK up: the SID's attack nibble, the Game Boy's attack follows", (p[FLD["sndAD"]] >> 4) > a0 and p[FLD["gbAtk"]] > 0,
      (a0, p[FLD["sndAD"]] >> 4, p[FLD["gbAtk"]]))
back(c, 3)
check("SHIFT+RETURN x3: closed", c.v("menuOn") == 0)

# ---------------------------------------------------------------- the dice
c.midi_in(0xC0, 0, ms=300)
p0 = patch(c)
rolls = []
for _ in range(6):
    shift(c, "/", ms=120)
    rolls.append(patch(c))
check("SHIFT + /: the patch rolled (effects change), a * on the name", any(x != p0 for x in rolls) and name(c).endswith("*"), name(c))
check("... the tone stays (SID wave, envelope)", all(x[:8] == p0[:8] for x in rolls), [x[:8] for x in rolls][:2])
last = rolls[-2]
c._raw_press("cbm", ms=8); c._raw_tap("/", ms=100); c._raw_release("cbm", ms=8)
check("C= + /: back to the patch before the last roll", patch(c) == last)
c.midi_in(0xC0, 1, ms=300)
c.midi_in(0xC0, 0, ms=300)                   # (FAT afresh, no dice)

# ---------------------------------------------------------------- the DH-100
c.set("useShs", 0)
c.tap("return", ms=60)
sel(c, "DEVICES"); c.tap("return", ms=60); sel(c, "CASIO"); c.tap("crsrright", ms=40)
back(c)
check("DH-100 in use: its page on the main menu", "CASIO DH-100" in "".join(rows(c)))
sel(c, "CASIO"); c.tap("return", ms=80)
r = rows(c)
check("DH-100 page: defaults", "VOLUME" in row_of(c, "BREATH ") and "NONE" in row_of(c, "BREATH FX1")
      and "NORMAL" in row_of(c, "BREATH FEEL") and "AS PLAYED" in row_of(c, "NOTES") and "PICK BANK" in row_of(c, "TONE"), r[2:11])
back(c, 2)
c.midi_in(0x90, 60, 100, ms=60)
c.midi_in(0xD0, 127, ms=60)
v_full = c.raw[0xD418] & 15
c.midi_in(0xD0, 0, ms=60)
v_none = c.raw[0xD418] & 15
c.midi_in(0xD0, 64, ms=60)
v_half = c.raw[0xD418] & 15
check("BREATH VOLUME: blow harder, louder (SID volume)", v_full == 15 and v_none <= 1 and 4 <= v_half <= 11, (v_none, v_half, v_full))
c.set("dhBreath", 2)
c.tap("return", ms=60); sel(c, "CASIO"); c.tap("return", ms=60); sel(c, "BREATH "); c.tap("crsrright", ms=40)
c._raw_press("lshift", ms=8); c._raw_tap("crsrright", ms=40); c._raw_release("lshift", ms=8)   # (FILTER, hook runs)
back(c, 2)
c.midi_in(0xD0, 120, ms=80)
cut_hi = c.raw[0xD416]
c.midi_in(0xD0, 20, ms=80)
cut_lo = c.raw[0xD416]
check("BREATH FILTER: FAT (no filter) gets the low-pass, the breath opens it", c.raw[0xD418] & 0x10 and cut_hi > 180
      and cut_lo < 60 and c.raw[0xD418] & 15 == 15, (cut_lo, cut_hi, hex(c.raw[0xD418])))
c.midi_in(0x80, 60, 0, ms=40)
# FX1: held GLIDE while blowing hard
c.tap("return", ms=60); sel(c, "CASIO"); c.tap("return", ms=60); sel(c, "BREATH FX1")
for _ in range(5 + A_GLIDE):
    c.tap("crsrright", ms=20)
check("BREATH FX1: HELD: GLIDE", "HELD: GLIDE" in row_of(c, "BREATH FX1"), row_of(c, "BREATH FX1"))
sel(c, "NOTES"); c.tap("crsrright", ms=30); c.tap("crsrright", ms=60)
check("NOTES: HARMONY", "HARMONY" in row_of(c, "NOTES"))
back(c, 2)
c.midi_in(0xD0, 30, ms=40)
check("breath soft: GLIDE not held", c.v("actCnt", 16)[A_GLIDE] == 0)
c.midi_in(0xD0, 100, ms=40)
check("breath hard: GLIDE held", c.v("actCnt", 16)[A_GLIDE] == 1 and c.v("glideK") > 0, c.v("glideK"))
c.midi_in(0xD0, 50, ms=40)
check("... still held a bit under (no flutter)", c.v("actCnt", 16)[A_GLIDE] == 1)
c.midi_in(0xD0, 10, ms=40)
check("... let go when the breath drops", c.v("actCnt", 16)[A_GLIDE] == 0)
c.midi_in(0xD0, 100, ms=10)
c.midi_in(0x90, 60, 100, ms=120)
check("HARMONY: one note plays it and a third above (C, E)", sorted(c.v("heldList", 8)[:c.v("heldCount")]) == [60, 64],
      c.v("heldList", 8))
c.midi_in(0x80, 60, 0, ms=200)
c.midi_in(0xD0, 0, ms=40)
c.midi_in(0xB0, 65, 127, ms=40)
check("portamento button: its task (GLIDE) held", c.v("actCnt", 16)[A_GLIDE] == 1)
c.midi_in(0xB0, 65, 0, ms=40)
check("... let go", c.v("actCnt", 16)[A_GLIDE] == 0)
c.midi_in(0xC0, 1, ms=300)
check("tone button 2: the PADS bank", c.screen_row(2).startswith("PADS"), c.screen_row(2))
c.midi_in(0xC0, 3, ms=300)
check("tone button 4: the BASS bank", c.screen_row(2).startswith("BASS"), c.screen_row(2))
c.midi_in(0xC0, 5, ms=300)
check("tone button 6: the dice", name(c).endswith("*") and c.v("undoOk") == 1, name(c))
c.midi_in(0xC0, 0, ms=300)
c.tap("return", ms=60); sel(c, "CASIO"); c.tap("return", ms=60); sel(c, "BREATH FX2"); c.tap("crsrright", ms=60)
back(c, 2)
c.midi_in(0xD0, 127, ms=60)
d_full = c.v("vibDepth")
c.midi_in(0xD0, 64, ms=60)
d_half = c.v("vibDepth")
check("BREATH FX2 VIBRATO DEPTH: FAT (none) gets the ADVANCED vibrato, deeper with the breath", d_full >= 55 and 20 <= d_half <= d_full * 2 // 3,
      (d_half, d_full))
c.midi_in(0xD0, 0, ms=40)
c.tap("return", ms=60); sel(c, "DEVICES"); c.tap("return", ms=60); sel(c, "CASIO"); c.tap("crsrright", ms=40)
back(c, 2)
check("DH-100 not in use: full volume, no breath jobs", c.v("brAtt") == 0 and c.v("brFilt") == 0 and c.v("breath") == 127)

# ---------------------------------------------------------------- the Synthcart
c.tap("return", ms=60); sel(c, "DEVICES"); c.tap("return", ms=60); sel(c, "ATARI"); c.tap("crsrright", ms=40)
back(c)
sel(c, "ATARI"); c.tap("return", ms=60)
sel(c, "TEMPO"); c.tap("crsrright", ms=60)
check("SYNTHCART TEMPO: SYNC snaps the tempo to one of its ten", c.v("syncTempo") == 2 and c.v("beat16L") | c.v("beat16H") << 8
      in (4267, 5334, 6400, 7467, 8534, 9600, 10667, 11734, 12801, 13867), c.v("beat16L") | c.v("beat16H") << 8)
back(c, 2)


def b16(c):
    return c.v("beat16L") | c.v("beat16H") << 8


c.set("scIdx", 4)
shift(c, ".", ms=60)
check("SHIFT + .: the next faster Synthcart tempo", b16(c) == 7467 and c.v("scIdx") == 3, b16(c))
shift(c, ",", ms=60)
shift(c, ",", ms=60)
check("SHIFT + , twice: two slower", b16(c) == 9600, b16(c))
c._raw_press(",", ms=60)
check(", held: about 3% slower", b16(c) == 9600 + 9600 // 32, b16(c))
c._raw_release(",", ms=60)
check("let go: back", b16(c) == 9600, b16(c))
c._raw_press(".", ms=60)
check(". held: about 3% faster", b16(c) == 9600 - 9600 // 32, b16(c))
c._raw_release(".", ms=60)
c.tap("return", ms=60); sel(c, "ATARI"); c.tap("return", ms=60); sel(c, "TRIM")
c.tap("crsrright", ms=40); c.tap("crsrright", ms=60)
check("TRIM +2: the beat a touch longer (2 x 1/1024)", "+2" in row_of(c, "TRIM") and b16(c) == 9600 + 2 * ((9600 >> 8) // 4),
      (row_of(c, "TRIM"), b16(c)))
back(c, 2)

# Synthcart tuning (the manual's table) and MATCH KEY
def tune_ccs(c, t0):
    return [b for t, st, a, b in c.midi() if t >= t0 and st & 0xF0 == 0xB0 and a == 103]


def sid_f(c):
    return c.raw[0xD400] | c.raw[0xD401] << 8


def nes_bends(c, t0):
    return [(st, a, b) for t, st, a, b in c.midi() if t >= t0 and st & 0xF0 == 0xE0]


c.midi_in(0xC0, 1, ms=300)                   # (WHISTLE? no: voice 2 = FAT 2, RAW: no detune)
c.tap("return", ms=60); sel(c, "ATARI"); c.tap("return", ms=60)
r = rows(c)
check("Synthcart page: TUNE TO SQUARE C -10, MATCH KEY ON (the defaults)", "SQUARE C -10" in row_of(c, "TUNE TO")
      and "ON" in row_of(c, "MATCH KEY") and c.v("tuneNow") == 1 and c.v("keyRoot") == 0, r[2:8])
back(c, 2)
c.midi_in(0x90, 60, 100, ms=60)
f_sq = sid_f(c)
c.midi_in(0x80, 60, 0, ms=300)
c.tap("return", ms=60); sel(c, "ATARI"); c.tap("return", ms=60); sel(c, "TUNE TO")
t0 = c.cpu.processorCycles
c.tap("crsrright", ms=40); c.tap("crsrright", ms=80)
check("TUNE TO BASS C# -35: the Game Boy's master tune 19, the key's root C#", "BASS" in row_of(c, "TUNE TO")
      and 19 in tune_ccs(c, t0) and c.v("keyRoot") == 1, (tune_ccs(c, t0), c.v("keyRoot")))
back(c, 2)
t0 = c.cpu.processorCycles
c.midi_in(0x90, 60, 100, ms=80)
f_bass = sid_f(c)
bends = nes_bends(c, t0)
c.midi_in(0x80, 60, 0, ms=300)
c.set("tuneC", 0)
c.midi_in(0x90, 60, 100, ms=80)
f_0 = sid_f(c)
c.midi_in(0x80, 60, 0, ms=300)
c.set("tuneC", 256 - 35)
check("... the SID 35 cents flat (SQUARE was 10)", 0.9785 < f_bass / f_0 < 0.9815 and 0.9935 < f_sq / f_0 < 0.9955,
      (f_0, f_sq, f_bass))
check("... the NES bent flat before its notes", any((b << 7 | a) < 8192 for st, a, b in bends), bends[:4])
c.tap("return", ms=60); sel(c, "ATARI"); c.tap("return", ms=60); sel(c, "MATCH KEY")
c.tap("crsrright", ms=40)
sel(c, "TUNE TO")
c._raw_press("lshift", ms=8); c._raw_tap("crsrright", ms=60); c._raw_release("lshift", ms=8)
check("MATCH KEY OFF, TUNE TO LEAD F -10: tuned, the key left alone", "LEAD" in row_of(c, "TUNE TO") and c.v("tuneNow") == 2
      and c.v("keyRoot") == 1, (c.v("tuneNow"), c.v("keyRoot")))
sel(c, "MATCH KEY")
c.tap("crsrright", ms=60)
check("MATCH KEY ON again: F", c.v("keyRoot") == 5)
back(c)
sel(c, "DEVICES"); c.tap("return", ms=60); sel(c, "ATARI")
t0 = c.cpu.processorCycles
c.tap("crsrright", ms=80)
check("Synthcart NOT USED: no tuning (master tune 64)", c.v("tuneNow") == 0 and 64 in tune_ccs(c, t0), tune_ccs(c, t0))
back(c, 2)

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
