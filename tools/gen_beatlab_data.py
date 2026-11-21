#!/usr/bin/env python3
"""The new Beat Lab's data -> patch/beatlab.json (copied to the site as
fatchip/beatlab/beatlab.json by tools/sync_chiplab.sh).

  clips       per MidiNES clip: bucket, sub-bucket, own pitch, length, name,
              neighbours (from patch/clips.json, tools/analyze_clips.py, and
              patch/clip-names.json, Reeve's Sample Lab names)
  timeSigs    the Beat Lab's (TIME_SIGS below; Fat Chip 64 takes them in v0.63)
  hatLayers, accentLayers, gbKits   Fat Chip 64's (patch/beats.json)
  gbNote      the Game Boy's drum notes (Fat Chip GB), by kit slot
  imports     starting points: the 25 beats (patch/beats.json) and the six
              older demo beats (v0.12-v0.60), in the new format

The new format (a beat): name, bpm, swing (%), grid (16, or 8 for an eighth
swing), ts (a time signature's name, or null = 4/4 and Fat Chip's choice),
gb (Game Boy kit), hats / accent (the layers it suggests), 16 pads
(index 0-15 = keys 1234 QWER ASDF ZXCV; each null or {clip, pitch|null}), and
parts A and B, each two lanes ("k": kick / snare / perc, "h": hats /
cymbals) of 32 steps written with the pads' keys ("." = rest)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import gen_beats  # noqa: E402

KEYS = "1234QWERASDFZXCV"
DOC = json.load(open(os.path.join(ROOT, "patch", "beats.json")))
CLIPS = json.load(open(os.path.join(ROOT, "patch", "clips.json")))["clips"]
NAMES = json.load(open(os.path.join(ROOT, "patch", "clip-names.json")))

# where the old lanes land: pad key per lane (the standard 8 on the two bottom rows)
PAD_OF = dict(bd="Z", sd="X", ch="C", oh="V", cp="S", ht="D", rm="F", mt="Q", lt="W", sh="E", cl="R",
              cy="1", rd="2", cb="3")
LANE1 = ["bd", "sd", "cp", "rm", "ht", "mt", "lt", "cb", "cl"]       # first wins a step
LANE2 = ["cy", "oh", "rd", "ch", "sh"]
# hats per curated kit (closed, open): pairs Reeve's hat-pair answers put together
HATS = dict(rock=("A12", "A27"), electro=("A14", "A42"), jungle=("A83", "A116"), dnb=("A94", "A116"),
            boombap=("A84", "A42"), soft=("A26", "A56"))
EXTRA = dict(cp="A24", ht="A43", mt="A46", lt="A47", rm="A63", cb="A53", cl="A41", sh="A62", cy="A54", rd="A82")


# the Beat Lab's time signatures (Reeve, 2026-11-21; Fat Chip 64 to take them in v0.63): the runs of the
# 32 steps that make each bar. 7/4 "7 in a row" was the same steps as 4+3, so it's gone; 5/8 and 7/8 take a
# bar from each half (3+2 from bar 1, 3+2 from bar 2) for a longer pattern; 6/8 sits after 3/4 (the same
# steps: twelve sixteenths a bar, grouped in threes rather than fours).
TIME_SIGS = [
    {"name": "4/4", "short": "4/4", "bars": [[[0, 16]], [[16, 16]]]},
    {"name": "3/4", "short": "3/4", "bars": [[[0, 12]], [[16, 12]]]},
    {"name": "6/8", "short": "6/8", "bars": [[[0, 12]], [[16, 12]]]},
    {"name": "5/4 (3+2)", "short": "5/4 3+2", "bars": [[[0, 12], [16, 8]]]},
    {"name": "6/4 (4+2)", "short": "6/4 4+2", "bars": [[[0, 16], [16, 8]]]},
    {"name": "7/4 (4+3)", "short": "7/4 4+3", "bars": [[[0, 16], [16, 12]]]},
    {"name": "7/4 (3+4)", "short": "7/4 3+4", "bars": [[[0, 12], [16, 16]]]},
    {"name": "5/8", "short": "5/8", "bars": [[[0, 10]], [[16, 10]]]},
    {"name": "7/8", "short": "7/8", "bars": [[[0, 14]], [[16, 14]]]},
]


def pad(clip):
    return {"clip": clip, "pitch": None}


def build_beat(name, bpm, swing, grid, ts, gb, hats, accent, kit, lanes_a, lanes_b, kick2=None):
    """lanes_*: old lane -> 32-step on/off strings."""
    pads = [None] * 16
    used = set(lanes_a) | set(lanes_b)
    k_ch, k_oh = HATS[kit]
    clips = dict(bd=gen_beats.KITS[kit]["kick"][1], sd=gen_beats.KITS[kit]["snare"][1], ch=k_ch, oh=k_oh, **EXTRA)
    for l in ("bd", "sd", "ch", "oh"):                  # the standard pads, always
        pads[KEYS.index(PAD_OF[l])] = pad(clips[l])
    pads[KEYS.index("A")] = pad(kick2 or gen_beats.KITS[kit]["kick"][2])
    pads[KEYS.index("S")] = pad(clips["cp"])
    pads[KEYS.index("D")] = pad(clips["ht"])
    for l in used:
        if pads[KEYS.index(PAD_OF[l])] is None:
            pads[KEYS.index(PAD_OF[l])] = pad(clips[l])

    def part(lanes):
        k, h = ["."] * 32, ["."] * 32
        for order, row in ((LANE1, k), (LANE2, h)):
            for l in reversed(order):                   # (so the first in the order lands last and wins)
                for s, c in enumerate(lanes.get(l, "")):
                    if c == "1":
                        row[s] = PAD_OF[l]
        return {"k": "".join(k), "h": "".join(h)}

    return {"name": name, "bpm": bpm, "swing": swing, "grid": grid, "ts": ts, "gb": gb, "hats": hats,
            "accent": accent, "pads": pads, "A": part(lanes_a), "B": part(lanes_b)}


def from_book():
    out = []
    for bank in DOC["banks"]:
        for b in bank["beats"]:
            A, B = {}, {}
            for l, s in b["lanes"].items():
                s = s.replace(" ", "")
                A[l] = "".join("1" if c in "xa" else "." for c in s)
                B[l] = "".join("1" if c in "xb" else "." for c in s)
            out.append(dict(bank=bank["name"], **build_beat(b["name"], b["bpm"], b["swing"], b["grid"], None, b["gb"],
                                                             b["hats"], b["accent"], gen_beats.KIT_OF[b["name"]], A, B)))
    return out


OLD = [   # the demo beats of v0.12-v0.60 (tools/gen_beats.py before v0.61): two bars each, no A / B
    dict(name="ELECTRO", bpm=124, swing=0, kit="electro",
         bd="X.....x...x..... X.....x...x..xo.", sd="....X.......X... ....X.......X..o",
         ch="XoxoXoxoXoxoXoxo XoxoXoxoXoxoXo..", oh="................ ..............x.",
         cl="..x.....X.....x. ..x.....X..x...."),
    dict(name="JUNGLE", bpm=168, swing=0, kit="jungle",
         bd="X.x.......Xx.... X.x.......x...o.", sd="....X..o.o.oX..o ....X..o.o.o..Xo",
         ch="x.X.x.X.x.X.x.X. x.X.x.X.x.X.xoXo", cy="X............... ................"),
    dict(name="DNB", bpm=174, swing=0, kit="dnb",
         bd="X.........x..... X.........x.o.x.", sd="....X..o....X..o ....X..o.o..X..o",
         ch="o.x.o.x.o.x.o.x. o.x.o.x.o.x.o...", oh="................ ..............X."),
    dict(name="BOOMBAP", bpm=90, swing=55, kit="boombap",
         bd="X......x..x....o X.x....x..x..x..", sd="....X..o....X... ....X..o.o..X..o",
         ch="X.x.x.x.X.x.x.x. X.x.x.x.X.x.x.o."),
    dict(name="ROCK", bpm=118, swing=0, kit="rock",
         bd="X.......X.x..... X.......X.x.....", sd="....X......oX... ....X...........",
         ch="X.x.X.x.X.x.X.x. X.x.X.x.........", cy="X............... ................",
         tom="................ ........1.1.2.33"),
    dict(name="6/8", bpm=60, swing=0, kit="soft", ts="6/8",
         bd="X.....x..... X.....x...o.", sd="...o..X..... ...o..X..oo.",
         ch="X.x.x.X.x.x. X.x.x.X.x.x.", cy="X........... ............"),
]


def from_old():
    out = []
    for b in OLD:
        lanes = {}
        for l in ("bd", "sd", "ch", "oh", "cy", "cl", "tom"):
            if l not in b:
                continue
            bars = b[l].split()
            steps = ["."] * 32
            for bi, bar in enumerate(bars):             # bar 2 starts at step 16 (6/8: 12 steps a bar)
                for j, c in enumerate(bar):
                    steps[16 * bi + j] = c
            if l == "tom":
                for t, name in (("1", "ht"), ("2", "mt"), ("3", "lt")):
                    lanes[name] = "".join("1" if c == t else "." for c in steps)
            else:
                lanes[l] = "".join("1" if c in "oxX" else "." for c in steps)
        out.append(dict(bank="OLD DEMOS", **build_beat(b["name"], b["bpm"], b["swing"], 16, b.get("ts"), "FC CHIP", "OFF",
                                                        "BACKBEAT", b["kit"], lanes, lanes)))
    return out


def main():
    clips = {}
    for cid, c in CLIPS.items():
        clips[cid] = {"bucket": c["bucket"], "sub": c["sub"], "pitch": c["pitch"], "ms": c["ring_ms"], "near": c["near"],
                      "name": NAMES.get(cid, "")}
    ts = TIME_SIGS
    gb_note = {str(gen_beats.GB_NOTE[l]): l for l in gen_beats.GB_NOTE}
    doc = {"about": "Fat Chip Beat Lab data (fat-chip-64 tools/gen_beatlab_data.py). Pads: keys " + KEYS + ".",
           "keys": KEYS, "clips": clips, "timeSigs": ts, "hatLayers": DOC["hatLayers"], "accentLayers": DOC["accentLayers"],
           "gbKits": DOC["gbKits"], "gbKitCC": gen_beats.GB_KIT_CC, "gbNote": gen_beats.GB_NOTE,
           "imports": from_book() + from_old()}
    path = os.path.join(ROOT, "patch", "beatlab.json")
    with open(path, "w") as f:
        json.dump(doc, f, separators=(",", ":"), ensure_ascii=False)
    print(f"{len(clips)} clips, {len(doc['imports'])} starting points -> {path}")
    del gb_note


if __name__ == "__main__":
    main()
