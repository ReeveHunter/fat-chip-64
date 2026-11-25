#!/usr/bin/env python3
"""Fat Chip 64 v0.46 / Fat Chip GB v0.10: the built-in sounds' Game Boy part,
for the Game Boy's ROM (../fat-chip-gb/src/gen/fcsounds.c).

Fat Chip 64 used to set the Game Boy up for a sound with about 45 CCs. Now,
for a built-in sound it sends one: CC 114 = the sound's number, and Fat Chip
GB applies the same CCs from its own copy. That copy is made here by running
Fat Chip 64 in the simulator, loading each built-in sound and recording the
CCs it sends the Game Boy (so the two can't drift apart in how they're
worked out). Run it whenever the built-in sounds change, then rebuild both.

    python3 tools/gen_gb_sounds.py [../fat-chip-gb]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ["FATCHIP_REAL"] = "1"               # (v0.65: the real build and patches, not the tests' copy)
os.environ.pop("FATCHIP_PATCHES", None)
sys.path.insert(0, os.path.join(HERE, "..", "test"))
sys.path.insert(0, HERE)
from sim import C64  # noqa: E402
import gen_patches  # noqa: E402

# eight characters on the Game Boy's screen
SHORT = {"DUTY LEAD": "DUTY LD", "SCREAMER": "SCREAMER", "WARBLE PAD": "WARB PAD",
         "DUTY SHIMMER PAD": "SHIMMER", "WARM SID PAD": "WARM PAD", "BREATHING PAD": "BREATHE",
         "ELECTRIC PIANO": "E.PIANO", "COMBO ORGAN": "ORGAN", "VIBRAPHONE": "VIBES",
         "GLIDE BASS": "GLD BASS", "WAVE BASS": "WAV BASS", "SEASICK CHORUS": "SEASICK",
         "REPEAT LEAD": "RPT LEAD", "ECHO PLUCK": "ECHO PLK", "TREMOLO GATE": "TREMGATE",
         # (2026-11-22: Reeve's Chip Lab patches)
         "FAT CHIPS": "FATCHIPS", "FAT ATTACK": "FAT ATK", "FAT VIBES": "FATVIBES", "FAT ORGAN": "FATORGAN",
         "FAT WARBLE": "FAT WARB", "CAVE MYSTERY PAD": "CAVE PAD", "DUTIFUL PADDING": "DUTIFUL",
         "MUSIC BOX": "MUSICBOX", "WHISTLING": "WHISTLNG", "EXCUSE ME": "EXCUSEME", "WHINGE CORE": "WHINGE",
         "FAST PUMP": "FASTPUMP", "SLOW PUMP": "SLOWPUMP", "BABY CANYON": "CANYON", "UNFAIR COIN TOSS": "COINTOSS",
         "DRIPPING UPWARD": "DRIPPING", "SINGER SEWING": "SEWING", "CHEEKY KOBOLD": "KOBOLD"}


def short(name):
    s = SHORT.get(name, name)
    return (s[:8]).ljust(8)


def capture():
    B = os.path.join(HERE, "..", "bin")
    c = C64(prg=os.path.join(B, "fatchip64-image.prg"), sym=os.path.join(B, "fatchip64.sym"), channels=None)   # (the real build)
    c.run_ms(500)
    gb = c.v("gbBase")
    out = []
    T = 0xCF80
    a = c.sym["SoundSet"]
    for i in range(len(gen_patches.PATCHES)):
        for k in range(20):                       # (forget what the Game Boy last got: send it all)
            c.raw[c.sym["gbCcS"] + k] = 0xFF
        c.set("gbFresh", 0)
        c.set("gbFc", 1)                          # (the CC way, to record it)
        cpu = c.cpu
        saved = (cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p)
        for k, b in enumerate([0x20, a & 255, a >> 8, 0x4C, (T + 3) & 255, (T + 3) >> 8]):
            c.raw[T + k] = b
        t0 = cpu.processorCycles
        cpu.pc, cpu.x = T, i
        while cpu.pc != T + 3:
            c.step()
        cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p = saved
        c.run_ms(400)
        assert c.v("soundMode") == i
        chans = [[], [], []]
        glob = []
        for t, s, d1, d2 in c.midi():
            if t < t0 or s & 0xF0 != 0xB0:
                continue
            v = (s & 15) - gb
            if not 0 <= v < 3:
                continue
            if d1 in (114, 113, 102):             # (the status after the CCs, and v0.63's channels and
                continue                          #  profile before them: not part of the sound)
            if d1 >= 102:
                glob.append((d1, d2))
            else:
                chans[v].append((d1, d2))
        out.append((gen_patches.PATCHES[i]["name"], chans, glob))
    return out


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "fat-chip-gb")
    sounds = capture()
    data, ofs = [], []
    for name, chans, glob in sounds:
        ofs.append(len(data))
        for ch in chans + [glob]:
            data.append(len(ch))
            for cc, v in ch:
                data += [cc, v]
    L = ["/* Generated file - do not edit. Made by fat-chip-64/tools/gen_gb_sounds.py",
         "   from Fat Chip 64's built-in sounds: per sound, the CCs Fat Chip 64 would",
         "   send the Game Boy (pulse 1, pulse 2, wave, then the globals), each list",
         "   its count and (CC, value) pairs. CC 114 n plays sound n. */",
         "#pragma bank 9", "#include <stdint.h>", "#include <gbdk/platform.h>", "",
         f"#define FC_SOUNDS_N {len(sounds)}",
         f"const uint8_t fc_sounds_n = {len(sounds)};",
         "const char fc_sound_names[FC_SOUNDS_N][8] = {"]
    for name, _, _ in sounds:
        L.append(f'    "{short(name)}",   /* {name} */'.replace(f'"{short(name)}"', "{" + ", ".join(f"'{ch}'" for ch in short(name)) + "}"))
    L.append("};")
    L.append(f"const uint16_t fc_sound_ofs[FC_SOUNDS_N] = {{ {', '.join(str(o) for o in ofs)} }};")
    L.append(f"const uint8_t fc_sound_data[{len(data)}] = {{")
    for k in range(0, len(data), 16):
        L.append("    " + ", ".join(str(b) for b in data[k:k + 16]) + ",")
    L.append("};")
    path = os.path.join(dest, "src", "gen", "fcsounds.c")
    open(path, "w").write("\n".join(L) + "\n")
    print(f"{len(sounds)} sounds, {len(data)} bytes -> {path}")


if __name__ == "__main__":
    main()
