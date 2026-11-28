#!/usr/bin/env python3
"""Fat Chip 64 v0.65: Reeve's Chip Lab patches (2026-11-22) are the built-in
patches, in banks FAT, DREAM, GLARE, CYCLE, SPARK. This runs the real build
(bin/); the other tests run bin/test/, the same program with the older patch
set (patch/patches-test.json), so they don't change when the patches do."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from sim import C64  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


P = json.load(open(os.path.join(ROOT, "patch", "patches.json")))
B = os.path.join(ROOT, "bin")
c = C64(prg=os.path.join(B, "fatchip64-image.prg"), sym=os.path.join(B, "fatchip64.sym"), channels=None)
c.run_ms(400)
check("header V0.67", "V0.67" in c.screen_row(0), c.screen_row(0))
check("25 built-in patches", c.sym["NUM_SOUNDS"] == 25 and len(P["patches"]) == 25, c.sym["NUM_SOUNDS"])
check("the banks: FAT, DREAM, GLARE, CYCLE, SPARK", [b["name"] for b in P["banks"]] == ["FAT", "DREAM", "GLARE", "CYCLE", "SPARK"])
want = ["FAT CHIPS", "FAT ATTACK", "FAT VIBES", "FAT ORGAN", "FAT WARBLE", "CAVE MYSTERY PAD", "DUTIFUL PADDING",
        "WARM SID PAD", "SEASICK CHORUS", "VIBRAPHONE", "MUSIC BOX", "WHISTLING", "DUTY LEAD", "EXCUSE ME", "WHINGE CORE",
        "FAST PUMP", "SLOW PUMP", "OH DANG", "LESLIE", "BABY CANYON", "UNFAIR COIN TOSS", "DRIPPING UPWARD",
        "SINGER SEWING", "CHEEKY KOBOLD", "CLAVICLE"]
check("in Reeve's order, bank by bank", [s for b in P["banks"] for s in b["slots"]] == want)
check("at start: FAT CHIPS", "FAT CHIPS" in c.screen_row(2), c.screen_row(2))
size = c.sym["PATCH_SIZE"]
ok = []
for i, name in enumerate(want):
    c.midi_in(0xC0, i, ms=150)
    ok.append(c.v("livePatch", size) == c.v(f"patch{i}", size) and name[:16] in c.screen_row(2))
check("each one plays (program change 0-24) with its name on screen", all(ok), [want[i] for i, k in enumerate(ok) if not k])
gbs = open(os.path.join(ROOT, "..", "fat-chip-gb", "src", "gen", "fcsounds.c")).read()
check("Fat Chip GB's copy has the same 25 (FAT CHIPS first)", "FC_SOUNDS_N 25" in gbs and "/* FAT CHIPS */" in gbs.split("fc_sound_names")[1][:200])

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
