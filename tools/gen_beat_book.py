#!/usr/bin/env python3
"""Fat Chip beats: the 25 beats in five banks, each with an A and a B part,
plus the hat layers, accent layers and time signatures -> patch/beats.json.

The beats listening page (reevehunter.com/fatchip/beats) plays this file; it
is also where the C64's beats will come from (tools/gen_beats.py, later).

Beats: two bars of 16 steps (sixteenths). A and B are written as separate
parts, one string per lane ('x' = a hit, '.' = rest, a space between bars);
the file stores each lane merged: '.' off, 'a' A only, 'b' B only, 'x' both.
Lanes:
  bd kick   sd snare  cp clap   rm rim    ht/mt/lt toms (hi / mid / lo)
  ch closed hat  oh open hat  cy crash  rd ride  sh shaker  cb cowbell  cl clave
swing: % of half a step (66 = triplet feel); grid 16 swings the odd sixteenths,
grid 8 the off-beat eighths (shuffles, jazz).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LANES = ["bd", "sd", "cp", "rm", "ht", "mt", "lt", "ch", "oh", "cy", "rd", "sh", "cb", "cl"]
GB_KITS = ["FC CHIP", "FC 808", "808", "909", "CR-78", "CHIP SQ", "CHIP LFSR"]


def B(name, bpm, A, Bp, swing=0, grid=16, hats="OFF", accent="BACKBEAT", gb="FC CHIP", nes=None):
    return dict(name=name, bpm=bpm, A=A, B=Bp, swing=swing, grid=grid, hats=hats, accent=accent, gb=gb, nes=nes or {})


E8 = "x.x.x.x.x.x.x.x. x.x.x.x.x.x.x.x."
E16 = "xxxxxxxxxxxxxxxx xxxxxxxxxxxxxxxx"
FOUR = "x...x...x...x... x...x...x...x..."
BACK = "....x.......x... ....x.......x..."
OFFB = "..x...x...x...x. ..x...x...x...x."

BANKS = [
    ("BASIC", [
        B("ROCK", 116,
          dict(bd="x.......x.x..... x.......x.x.....", sd=BACK, ch=E8, cy="x............... ................"),
          dict(bd="x.......x.x..x.. x.x.....x.x.....", sd="....x......xx... ....x...........", ch="x.x.x.x.x.x.x.x. x.x.x.x.x.......",
               ht="................ ............xx..", mt="................ ..............x.", lt="................ ...............x",
               cy="x............... ................"),
          accent="BACKBEAT", gb="909", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
        B("DISCO", 120,
          dict(bd=FOUR, sd=BACK, ch="x...x...x...x... x...x...x...x...", oh=OFFB),
          dict(bd=FOUR, sd=BACK, cp=BACK, ch="xx.xxx.xxx.xxx.x xx.xxx.xxx.xxx.x", oh=OFFB, cb="................ ..........x.x..."),
          accent="OFFBEAT", gb="808", nes=dict(bd={"type": "Punchy"}, sd={"perc": "Clap"})),
        B("SYNTHPOP", 112,
          dict(bd="x.......x....... x.......x.....x.", sd=BACK, ch=E8),
          dict(bd="x..x....x.x..... x..x....x.x...x.", sd=BACK, cp=BACK, ch=E16, oh="................ ..............x."),
          accent="DOWNBEAT", gb="808", nes=dict(bd={"tag": "Electro"}, sd={"type": "Electronic"})),
        B("FUNK", 100,
          dict(bd="x.........x..... x.....x...x.....", sd="....x..x.x..x..x ....x..x.x..x...", ch=E8,
               oh="......x......... ..............x."),
          dict(bd="x.x.......x..x.. x.....x.x..x....", sd="....x..x.x.xx..x ....x..x.x..x.x.", ch="xxxxxxx.xxxxxxx. xxxxxxx.xxxxxx..",
               oh="......x......... ..............x."),
          accent="SYNCOPATED", gb="FC 808", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
        B("MOTORIK", 132,
          dict(bd="x.......x.x..... x.......x.x.....", sd=BACK, ch=E8),
          dict(bd="x...x...x.x.x... x...x...x.x.x...", sd=BACK, ch=E16, oh="................ ..............x."),
          accent="FLAT", gb="CHIP SQ", nes=dict(bd={"type": "Punchy"}, sd={"type": "Electronic"})),
    ]),
    ("CHILL", [
        B("LO-FI", 76,
          dict(bd="x.......x.x..... x......x..x.....", sd=BACK, ch=E8, rm="................ ..............x."),
          dict(bd="x......x..x....x x.x....x..x.....", sd="....x..x....x... ....x..x.x..x...", ch=E8, sh="..x...x...x...x. ..x...x...x...x."),
          swing=58, accent="SHUFFLE", gb="FC 808", nes=dict(bd={"tag": "Lo-fi", "type": "Short/Clicky"}, sd={"type": "Brushy"})),
        B("TRIP HOP", 88,
          dict(bd="x.........x..... x......x..x.....", sd="........x....... ........x.......", ch=E8),
          dict(bd="x..x......x..x.. x......x..x..x..", sd="........x......x ........x..x....", ch=E8,
               oh="......x......... ......x........."),
          swing=20, accent="DOWNBEAT", gb="909", nes=dict(bd={"type": "Long"}, sd={"type": "Fat"})),
        B("DUB", 72,
          dict(bd="x.......x....... x.......x.......", rm=BACK, ch="x.x.x.x.x.x.x.x. x.x.x.x.x.x.x.x."),
          dict(bd=FOUR, rm=BACK, ch=OFFB, oh="................ ..............x.", cy="x............... ................"),
          swing=30, accent="OFFBEAT", gb="CR-78", nes=dict(bd={"type": "Long"})),
        B("TRAP", 140,
          dict(bd="x......x..x..... x.....x...x.....", cp="........x....... ........x.......", ch=E8),
          dict(bd="x......x..x...x. x.x...x...x..x..", cp="........x....... ........x......x", ch="x.x.x.xxx.x.xxxx x.x.x.x.xxxxx.x.",
               oh="................ ......x........."),
          accent="FLAT", gb="808", nes=dict(bd={"type": "Long", "tag": "Trap"}, sd={"perc": "Clap"})),
        B("SLOW JAM", 68,
          dict(bd="x.......x..x.... x.......x.......", rm=BACK, ch=E8),
          dict(bd="x..x....x..x..x. x.......x.x.....", rm="....x.......x... ....x.......x..x", ch=E8,
               sh="x.xxx.xxx.xxx.xx x.xxx.xxx.xxx.xx"),
          swing=30, accent="BACKBEAT", gb="808", nes=dict(bd={"type": "Long"})),
    ]),
    ("BREAK", [
        B("DNB", 174,
          dict(bd="x.........x..... x.........x.....", sd=BACK, ch=E8),
          dict(bd="x.........x..x.. x.........x.x.x.", sd="....x..x.x..x..x ....x..x.x..x..x", ch=E8,
               oh="................ ..............x."),
          accent="BACKBEAT", gb="909", nes=dict(bd={"tag": "DnB", "type": "Punchy"}, sd={"type": "Jungle"})),
        B("JUNGLE", 168,
          dict(bd="x.x.......xx.... x.x.......x.....", sd="....x..x.x.xx..x ....x..x.x.x..x.", ch=E8),
          dict(bd="x.x.......x..... ..x.......x...x.", sd="....x..x.x..x.x. .x.xx..x.x.x.xxx", ch=E8,
               cy="x............... ................"),
          accent="BACKBEAT", gb="FC CHIP", nes=dict(bd={"tag": "DnB", "type": "Layered"}, sd={"type": "Jungle"})),
        B("BREAKS", 130,
          dict(bd="x.........x..... x.x.......x.....", sd=BACK, ch=E8),
          dict(bd="x.x.......x..x.. x.x.......x.x...", sd="....x..x....x... ....x..x..x.x...", ch=E8,
               oh="......x.......x. ......x.......x."),
          accent="BACKBEAT", gb="909", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
        B("HOUSE", 124,
          dict(bd=FOUR, cp=BACK, oh=OFFB),
          dict(bd=FOUR, cp="....x.......x... ....x.......x..x", oh=OFFB, ch="xx.xxx.xxx.xxx.x xx.xxx.xxx.xxx.x",
               sh="................ ................"),
          accent="OFFBEAT", gb="909", nes=dict(bd={"type": "Punchy"}, sd={"perc": "Clap"})),
        B("TECHNO", 130,
          dict(bd=FOUR, ch=OFFB),
          dict(bd=FOUR, ch=OFFB, cp=BACK, rd=E8, rm="...x..x....x..x. ...x..x....x..x."),
          accent="FLAT", gb="909", nes=dict(bd={"type": "Punchy"}, sd={"perc": "Clap"})),
    ]),
    ("GLOBE", [
        # salsa / cumbia / bossa: the 16 steps are eighths of the clave's two bars
        B("SALSA", 100,
          dict(cl="x..x..x...x.x... x..x..x...x.x...", cb="x...x.x.x...x.x. x...x.x.x...x.x.",
               mt="......x......... ......x.........", lt="..........x.x... ..........x.x...", bd="...x.......x.... ...x.......x...."),
          dict(cl="x..x..x...x.x... x..x..x...x.x...", rm="x.xx.x.xx.x.x.xx x.xx.x.xx.x.x.xx",
               mt="..x...x.....x... ..x...x.....x...", lt="..........x.x..x ..........x.x..x", bd="...x.......x.... ...x.......x...."),
          accent="FLAT", hats="NONE", gb="CR-78", nes=dict(bd={"type": "Short/Clicky"})),
        B("CUMBIA", 92,
          dict(bd="x.......x....... x.......x.......", rm=BACK, sh="x.xxx.xxx.xxx.xx x.xxx.xxx.xxx.xx"),
          dict(bd="x.......x....... x.......x.......", rm=BACK, sh="x.xxx.xxx.xxx.xx x.xxx.xxx.xxx.xx",
               mt="..x...x...x...x. ..x...x...x...x.", lt="......xx......xx ......xx......xx"),
          accent="OFFBEAT", hats="NONE", gb="CR-78", nes=dict(bd={"type": "Short/Clicky"})),
        B("REGGAE", 76,
          dict(bd="........x....... ........x.......", rm="........x....... ........x.......", ch=E8),
          dict(bd="........x....... ........x.......", rm="........x....... ........x.......", ch=E8,
               oh="..x...x...x...x. ..x...x...x...x.", ht="................ ............x...", mt="................ .............x..",
               lt="................ ..............xx"),
          swing=33, accent="OFFBEAT", gb="CR-78", nes=dict(bd={"type": "Long"})),
        B("BOSSA", 75,
          dict(bd="x..xx..xx..xx..x x..xx..xx..xx..x", rm="x..x..x...x..x.. ..x..x...x..x...", ch=E8),
          dict(bd="x..xx..xx..xx..x x..xx..xx..xx..x", rm="..x..x...x..x... x..x..x...x..x..", sh=E16),
          accent="FLAT", gb="CR-78", nes=dict(bd={"type": "Short/Clicky"}, sd={"type": "Brushy"})),
        B("AFROBEAT", 110,
          dict(bd="x.....x.x.....x. x...x.x.......x.", sd="....x.......x... ....x..x....x...", ch=E16, cb="x.x.x..x.x.x.x.. x.x.x..x.x.x.x.."),
          dict(bd="x.....x.x.....x. x...x.x.......x.", sd="....x.......x... ....x..x....x...", ch=E16, cb="x.x.x..x.x.x.x.. x.x.x..x.x.x.x..",
               oh="..x...x...x...x. ..x...x...x...x.", mt="..x.......x..x.. ..x.......x..x..", lt="......x.......x. ......x.......xx"),
          accent="SYNCOPATED", gb="808", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
    ]),
    ("SWING", [
        B("SHUFFLE", 100,
          dict(bd="x.......x....... x.......x.......", sd=BACK, ch=E8),
          dict(bd="x......xx....... x......xx.....x.", sd="....x..x....x..x ....x..x....x...", ch=E8,
               oh="................ ..............x."),
          swing=66, grid=8, accent="BACKBEAT", gb="FC CHIP", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
        B("BOOM BAP", 90,
          dict(bd="x......x..x..... x.x....x..x.....", sd=BACK, ch=E8),
          dict(bd="x......x..x....x x.x....x..x..x..", sd="....x..x....x... ....x..x.x..x..x", ch=E8),
          swing=55, accent="BACKBEAT", gb="FC 808", nes=dict(bd={"tag": "Boombap", "type": "Punchy"}, sd={"tag": "Boombap", "type": "Fat"})),
        B("NEW JACK", 104,
          dict(bd="x..x..x...x..... x..x..x...x.x...", cp=BACK, ch="x.xxx.xxx.xxx.xx x.xxx.xxx.xxx.xx"),
          dict(bd="x..x..x...x..... x..x..x...x.x...", cp="....x..x....x... ....x..x....x..x", sd=BACK,
               ch="x.xxx.xxx.xxx.xx x.xxx.xxx.xxx.xx", sh=E16),
          swing=60, accent="BACKBEAT", gb="808", nes=dict(bd={"type": "Punchy"}, sd={"perc": "Clap"})),
        B("JAZZ", 140,
          dict(rd="x...x.x.x...x.x. x...x.x.x...x.x.", ch=BACK, bd=FOUR),
          dict(rd="x...x.x.x...x.x. x...x.x.x...x.x.", ch=BACK, bd="x.........x..... ......x.........",
               sd="......x.......x. ..x....x..x..x.."),
          swing=66, grid=8, hats="NONE", accent="BACKBEAT", gb="CR-78", nes=dict(sd={"type": "Brushy"})),
        B("GO-GO", 96,
          dict(bd="x.....x...x..... x.....x...x.x...", sd="....x..x....x... ....x..x.x..x...", ch=E16, cb="x..x..x...x.x... x..x..x...x.x..."),
          dict(bd="x.....x...x..... x.....x...x.x...", sd="....x..x....x... ....x..x.x..x...", ch=E16, cb="x..x..x...x.x... x..x..x...x.x...",
               mt="..x...x.....x.x. ..x...x.....x.x.", lt="....x.......x..x ....x.......x..x", oh="......x......... ......x........."),
          swing=50, accent="SYNCOPATED", gb="CR-78", nes=dict(bd={"type": "Punchy"}, sd={"type": "Fat"})),
    ]),
]

# hat layers, laid over any beat in place of its own closed / open hats. One bar
# repeated; "grid": 16 = sixteenths, 12 = triplet eighths (three to a beat).
HAT_LAYERS = [
    dict(name="OFF", desc="the beat's own hats"),
    dict(name="NONE", grid=16, ch="", oh="", desc="no hats"),
    dict(name="8THS", grid=16, ch="x.x.x.x.x.x.x.x."),
    dict(name="16THS", grid=16, ch="xxxxxxxxxxxxxxxx"),
    dict(name="QUARTERS", grid=16, ch="x...x...x...x..."),
    dict(name="OFFBEAT", grid=16, oh="..x...x...x...x."),
    dict(name="DISCO", grid=16, ch="x...x...x...x...", oh="..x...x...x...x."),
    dict(name="GALLOP", grid=16, ch="x.xxx.xxx.xxx.xx"),
    dict(name="SKIP", grid=16, ch="x.x.x.xxx.x.x.xx"),
    dict(name="OPEN 16THS", grid=16, ch="xxx.xxx.xxx.xxx.", oh="...x...x...x...x"),
    dict(name="ROLLS", grid=16, ch="x.x.x.x.x.xxxxxx"),
    dict(name="TRIPLETS", grid=12, ch="xxxxxxxxxxxx", desc="triplet eighths over a straight beat"),
    dict(name="TRIP SWING", grid=12, ch="x.xx.xx.xx.x", desc="the shuffle's long-short on triplets"),
    dict(name="TRIP OPEN", grid=12, ch="xx.xx.xx.xx.", oh="..x..x..x..x"),
]

# accent layers: S strong, n normal, s soft, one per step of a bar (BUILD: two bars).
# Hats, cymbals and percussion follow fully; kick and snare only take the strong steps.
ACCENT_LAYERS = [
    dict(name="FLAT", steps="nnnnnnnnnnnnnnnn"),
    dict(name="DOWNBEAT", steps="SnsnnnsnSnsnnnsn"),
    dict(name="BACKBEAT", steps="nnsnSnsnnnsnSnsn"),
    dict(name="OFFBEAT", steps="snSnsnSnsnSnsnSn"),
    dict(name="SYNCOPATED", steps="SnsSnsSnsnSnSnsn"),
    dict(name="SHUFFLE", steps="nsnsnsnsnsnsnsns"),
    dict(name="BUILD", steps="ssssssssnnnnnnnn nnnnnnnnSSSSSSSS"),
    dict(name="HUMAN", steps="random", desc="small random changes"),
]

# time signatures: each bar of the cycle is a list of [first step, steps] taken
# from the beat's 32 steps (the kick stays on the downbeat)
TIME_SIGS = [
    dict(name="4/4", short="4/4", bars=[[[0, 16]], [[16, 16]]]),
    dict(name="3/4", short="3/4", bars=[[[0, 12]], [[16, 12]]]),
    dict(name="5/4 (3+2)", short="5/4 3+2", bars=[[[0, 12], [16, 8]]]),
    dict(name="6/4 (4+2)", short="6/4 4+2", bars=[[[0, 16], [16, 8]]]),
    dict(name="7/4 (4+3)", short="7/4 4+3", bars=[[[0, 16], [16, 12]]]),
    dict(name="7/4 (3+4)", short="7/4 3+4", bars=[[[0, 12], [16, 16]]]),
    dict(name="7/4 (7 in a row)", short="7/4 7", bars=[[[0, 28]]]),
    dict(name="5/8 (3+2)", short="5/8 3+2", bars=[[[0, 6], [16, 4]]]),
    dict(name="7/8 (4+3)", short="7/8 4+3", bars=[[[0, 8], [16, 6]]]),
    dict(name="7/8 (2+2+3)", short="7/8 2+2+3", bars=[[[0, 4], [8, 4], [16, 6]]]),
]


def merge(name, A, Bp):
    out = {}
    for lane in set(A) | set(Bp):
        assert lane in LANES, (name, lane)
        a = A.get(lane, "").replace(" ", "")
        b = Bp.get(lane, "").replace(" ", "")
        for s in (a, b):
            assert len(s) in (0, 32) and set(s) <= set("x."), (name, lane, len(s))
        a = a or "." * 32
        b = b or "." * 32
        m = "".join("x" if p == "x" and q == "x" else "a" if p == "x" else "b" if q == "x" else "." for p, q in zip(a, b))
        if m.strip("."):
            out[lane] = m[:16] + " " + m[16:]
    return {k: out[k] for k in LANES if k in out}


def build():
    names = {h["name"] for h in HAT_LAYERS}
    accents = {a["name"] for a in ACCENT_LAYERS}
    banks = []
    for bank, beats in BANKS:
        assert len(beats) == 5 and len(bank) == 5, bank
        out = []
        for b in beats:
            assert len(b["name"]) <= 8 and b["hats"] in names and b["accent"] in accents and b["gb"] in GB_KITS, b["name"]
            out.append(dict(name=b["name"], bpm=b["bpm"], swing=b["swing"], grid=b["grid"], hats=b["hats"],
                            accent=b["accent"], gb=b["gb"], nes=b["nes"], lanes=merge(b["name"], b["A"], b["B"])))
        banks.append(dict(name=bank, beats=out))
    for h in HAT_LAYERS:
        for k in ("ch", "oh"):
            if h.get(k):
                assert len(h[k]) == h["grid"], h["name"]
    for a in ACCENT_LAYERS:
        assert a["steps"] == "random" or len(a["steps"].replace(" ", "")) in (16, 32), a["name"]
    doc = dict(lanes=LANES, gbKits=GB_KITS, banks=banks, hatLayers=HAT_LAYERS, accentLayers=ACCENT_LAYERS, timeSigs=TIME_SIGS)
    path = os.path.join(ROOT, "patch", "beats.json")
    with open(path, "w") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    return sum(len(b["beats"]) for b in banks)


if __name__ == "__main__":
    print(build(), "beats -> patch/beats.json")
