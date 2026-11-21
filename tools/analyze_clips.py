#!/usr/bin/env python3
"""Measure the MidiNES DMC clips and rank each one's nearest neighbours, for
the Beat Lab and for Fat Chip 64's VARY.

  analyze_clips.py <dmc dir> [sound-sorter export.json] [out.json]

(the export defaults to patch/sound-sorter-2026-11-21.json)

The dmc dir holds bankA_n000.dmc ... bankB_n127.dmc (fat-chip/midines-dmc/dmc,
decoded from recordings; not kept in this repo). The Sorter export carries
Reeve's buckets (the word on what each clip is), his go-together rounds and
his style tags. Writes patch/clips.json: per clip its bucket, measurements and
up to NEIGHBOURS neighbours, closest first. No sample data goes in it.

Neighbours come only from the same bucket (or a bucket the clip "also works
as"), the same sub-bucket first; within that, by how alike the clips measure
(length, decay, attack, low end, brightness, level), pulled closer by Sorter
rounds that put them together and by shared style tags. Only the drum buckets
vary (kick, snare, layered, hats & cymbals, toms & percussion): vocals, FX,
tonal clips and the sweep get no neighbours and are never swapped in."""
import json
import math
import os
import sys

import numpy as np
from scipy.ndimage import uniform_filter1d
from scipy.signal import butter, sosfiltfilt

HERE = os.path.dirname(os.path.abspath(__file__))
NEIGHBOURS = 6
SWAPPABLE = {"kick", "snare", "layer", "hats", "perc"}   # the drum buckets: only these vary
HZ = [4181.7, 4709.9, 5264.0, 5593.0, 6258.0, 7046.4, 7919.4, 8363.4, 9419.9, 11186.1, 12604.0, 13982.6,
      16884.6, 21306.8, 24858.0, 33143.9]


def native(bank, note):                     # the drums at the fastest rate, the rest of bank B at 12
    return 15 if bank == "A" or note <= 21 else 12


def is_sweep(cid):
    return cid[0] == "B" and int(cid[1:]) >= 95


def render(data):
    """The DAC level after each bit: bit 0 first, 1 = up 2, 0 = down 2, held in 0..127."""
    bits = np.unpackbits(np.frombuffer(data, np.uint8), bitorder="little").astype(np.int16)
    out = np.empty(len(bits), np.float32)
    v = 64
    for i, b in enumerate(bits):
        if b:
            if v <= 125:
                v += 2
        elif v >= 2:
            v -= 2
        out[i] = v
    return out


def measure(data, rate):
    x = render(data).astype(np.float64)
    bits = np.unpackbits(np.frombuffer(data, np.uint8), bitorder="little")
    zeros = np.nonzero(bits == 0)[0]
    if len(zeros) and len(x) - zeros[-1] > 8:   # (most clips end in a run of 1s: a ramp up to the top of the DAC, a click; not the sound)
        x = x[:zeros[-1] + 1]
    x -= x.mean()
    if len(x) > 24:                         # take out the DAC's slow wander (below ~30 Hz)
        x = sosfiltfilt(butter(2, 30, "highpass", fs=rate, output="sos"), x, padlen=min(len(x) - 1, 3 * int(rate * 0.01)))
    w = max(1, int(rate * 0.005))           # 5 ms RMS
    env = np.sqrt(uniform_filter1d(x * x, w, mode="nearest"))
    pk = float(env.max()) or 1e-9
    ipk = int(env.argmax())
    above = np.nonzero(env > pk * 0.0316)[0]            # -30 dB
    ring = (above[-1] if len(above) else 0) / rate
    after = np.nonzero(env[ipk:] < pk * 0.1)[0]         # -20 dB after the peak
    decay = (after[0] if len(after) else len(env) - ipk) / rate
    seg = x[:int(rate * 0.25)] * np.hanning(min(len(x), int(rate * 0.25)))
    p = np.abs(np.fft.rfft(seg, n=8192)) ** 2
    f = np.fft.rfftfreq(8192, 1 / rate)
    tot = p[f > 20].sum() or 1e-9
    low = p[(f > 20) & (f < 200)].sum() / tot
    high = p[f >= 3000].sum() / tot
    cen = (p[f > 20] * np.log2(f[f > 20])).sum() / tot
    return {"ms": round(len(bits) / rate * 1000, 1), "ring_ms": round(ring * 1000, 1), "attack_ms": round(ipk / rate * 1000, 1),
            "decay_ms": round(decay * 1000, 1), "low": round(float(low), 3), "high": round(float(high), 3),
            "bright": round(float(2 ** cen)), "level": round(pk, 2)}


def sorter_links(rounds):
    """Net together-minus-apart from the go-together rounds (hat-pair answers: the latest per pair)."""
    t, a = {}, {}
    pk = lambda x, y: (x, y) if x < y else (y, x)
    latest = {}
    for r in rounds:
        fl = [i for b in r["b"] for i in b]
        if r["mode"] == "hats" and len(fl) == 2:
            k = pk(*fl)
            if k not in latest or latest[k]["t"] <= r["t"]:
                latest[k] = r
    for r in rounds:
        fl = [i for b in r["b"] for i in b]
        if r["mode"] == "hats" and len(fl) == 2 and latest[pk(*fl)] is not r:
            continue
        for i, B in enumerate(r["b"]):
            for x in range(len(B)):
                for y in range(x + 1, len(B)):
                    k = pk(B[x], B[y]); t[k] = t.get(k, 0) + 1
            for C in r["b"][i + 1:]:
                for u in B:
                    for v in C:
                        k = pk(u, v); a[k] = a.get(k, 0) + 1
    out = {}
    for k in set(t) | set(a):
        n = t.get(k, 0) + a.get(k, 0)
        out[k] = (t.get(k, 0) - a.get(k, 0)) / n          # -1 always apart .. +1 always together
    return out


def main():
    dmc = sys.argv[1]
    sorter = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "patch", "sound-sorter-2026-11-21.json")
    out_path = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "..", "patch", "clips.json")
    S = json.load(open(sorter))
    B = S["buckets"]                                    # id -> [bucket, sub, also, also sub, checked, sub checked]
    links = sorter_links(S["rounds"])
    tags = {k: {t for t in v if t.startswith("style:")} for k, v in S.get("tags", {}).items()}

    clips = {}
    for bank in "AB":
        for note in range(128):
            cid = f"{bank}{note}"
            data = open(os.path.join(dmc, f"bank{bank}_n{note:03d}.dmc"), "rb").read()
            b = B["SWEEP"] if is_sweep(cid) else B[cid]
            m = measure(data, HZ[native(bank, note)])
            clips[cid] = {"bucket": b[0], "sub": "sweep" if is_sweep(cid) else b[1], "also": b[2], "alsoSub": b[3],
                          "pitch": native(bank, note), "bytes": len(data), **m}

    # how alike two clips measure: z-scored features, weighted
    ids = [c for c in clips if not is_sweep(c)]
    feats = np.array([[math.log(clips[c]["ring_ms"] + 5), math.log(clips[c]["decay_ms"] + 2), math.log(clips[c]["attack_ms"] + 1),
                       clips[c]["low"], clips[c]["high"], math.log2(clips[c]["bright"] + 50), clips[c]["level"]] for c in ids])
    feats = (feats - feats.mean(0)) / (feats.std(0) + 1e-9)
    W = np.array([1.5, 1.0, 0.5, 1.0, 0.8, 1.2, 0.5])
    row = {c: i for i, c in enumerate(ids)}

    def homes(c):
        h = [(clips[c]["bucket"], clips[c]["sub"])]
        if clips[c]["also"]:
            h.append((clips[c]["also"], clips[c]["alsoSub"]))
        return h

    for c in clips:
        if clips[c]["bucket"] not in SWAPPABLE:   # vocals, FX, tonal clips and the sweep always play as chosen
            clips[c]["near"] = []
            continue
        top, sub = clips[c]["bucket"], clips[c]["sub"]
        cand = []
        for o in ids:
            if o == c or clips[o]["bucket"] not in SWAPPABLE:
                continue
            oh = homes(o)
            if not any(bk == top for bk, _ in oh) and not (clips[c]["also"] and any(bk == clips[c]["also"] for bk, _ in oh)):
                continue
            same_sub = any(bk == top and (sb == sub or not sub) for bk, sb in oh)
            d = float(np.sqrt((W * (feats[row[c]] - feats[row[o]]) ** 2).sum()))
            k = (c, o) if c < o else (o, c)
            d -= 0.8 * links.get(k, 0)
            ta, tb = tags.get(c, set()), tags.get(o, set())
            if ta and tb:
                d -= 0.4 * len(ta & tb) / len(ta | tb)
            d += 0.0 if same_sub else 1.5
            d += 0.0 if oh[0][0] == top else 0.5        # (living in another bucket and only also working here)
            cand.append((d, o))
        cand.sort()
        clips[c]["near"] = [o for _, o in cand[:NEIGHBOURS]]

    doc = {"about": "MidiNES DMC clips: Reeve's buckets (Sound Sorter, 2026-11-21), measurements at each clip's own "
                    "pitch, and up to %d neighbours each, closest first (tools/analyze_clips.py)." % NEIGHBOURS,
           "clips": clips}
    with open(out_path, "w") as f:
        json.dump(doc, f, indent=0, separators=(",", ":"))
    print(f"{len(clips)} clips -> {out_path}")


if __name__ == "__main__":
    main()
