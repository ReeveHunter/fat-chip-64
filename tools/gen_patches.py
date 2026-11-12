#!/usr/bin/env python3
"""Fat Chip 64's built-in patches: patch/patches.json -> src/soundtab.asm.

The patches are written in the shared units of patch/effects.json (ms, Hz,
cents, %), the same units Chip Lab and Fat Chip GB use. This turns each one
into the bytes Fat Chip 64 plays from (its live patch fields): SID registers,
Fat Chip GB CC values, and the C64's own MidiNES envelope numbers.

An effect is on when the patch lists it; "on": [chips] limits it to those
chips. Settings a patch leaves out take the default from effects.json.
What a chip can't do yet (SID ring / sync, pan, the filter's envelope times,
...) is left out here; check_effects.py lists the full definition.

Run with --diff OLD.asm to compare every field with an older soundtab.asm.
"""
import json
import math
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
NAME_LEN = 16                      # the name as the screen shows it

DEF = json.load(open(os.path.join(ROOT, "patch", "effects.json")))
PATCHES = json.load(open(os.path.join(ROOT, "patch", "patches.json")))["patches"]
EFFECTS = {e["id"]: e for e in DEF["effects"]}
SID_ATK = DEF["lists"]["sidAttackMs"]
SID_DR = DEF["lists"]["sidDecayReleaseMs"]

# ------------------------------------------------------------ chip maths
GB_TICK_HZ = 59.73
GB_LFO_HZ = [max(1, min(65535, int(round(0.08 * (24 / 0.08) ** (i / 31) * 65536 / GB_TICK_HZ)))) * GB_TICK_HZ / 65536
             for i in range(32)]                      # Fat Chip GB's 32 LFO rates
GB_LFO_DEPTH = [int(round(192 * (d / 31) ** 2.2)) if d else 0 for d in range(32)]   # 1/16 semitone, full swing
GB_GLIDE = [0] + [max(3, int(round(256 * 0.6 ** (g * 0.55)))) for g in range(1, 16)]
GB_SHAPES = {"TRI": 0, "SINE": 0, "SAW DOWN": 1, "SAW UP": 2, "SQUARE": 3, "RANDOM": 4}
SID_WAVES = [0x10, 0x20, 0x40, 0x80, 0x30, 0x50, 0x60, 0x70]
REPEAT_NATIVE = [0, 1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]   # 1/16T: the C64 has no 1/16T yet: 1/16


def cc(param, mx):
    """Fat Chip GB scales a CC as value * (max + 1) >> 7: the smallest CC giving `param`."""
    return min(127, math.ceil(param * 128 / (mx + 1)))


def inc4(hz):                      # 16-bit phase step per 4 ms
    return int(round(hz * 65536 / 250))


def nearest(values, x, log=True):
    f = (lambda v: math.log(max(v, 1e-6))) if log else (lambda v: v)
    return min(range(len(values)), key=lambda i: abs(f(values[i]) - f(x)))


def gb_env_n(ms, level):
    """Fat Chip GB envelope 0-7: a volume step every n/64 s, `level` steps."""
    if level <= 0:
        return 0
    return max(0, min(7, round(ms / 1000 * 64 / level)))


def gb_glide(ms):
    """Fat Chip GB glide 0-15: closes a fraction of the gap each 1/60 s."""
    if not ms:
        return 0
    def tau(g):
        return 1000 / GB_TICK_HZ / -math.log(1 - GB_GLIDE[g] / 256)
    return min(range(1, 16), key=lambda g: abs(math.log(tau(g)) - math.log(ms)))


def gb_depth(cents):
    return min(range(32), key=lambda d: abs(GB_LFO_DEPTH[d] * 100 / 16 - cents))


def nes_env(a, d, s, r, peak):
    """(attack step 8.8 per 10 ms, decay step, sustain level, release factor), times in s."""
    sus = max(1, round(peak * s)) if s > 0 else 0
    atk = 0 if a < 0.015 else max(1, min(255, round(peak * 256 / (a * 100))))
    dec = 0 if d == 0 or sus >= peak else max(1, min(255, round((peak - sus) * 256 / (d * 100))))
    rel = 0 if r < 0.01 else max(1, min(68, round(10240 / (r * 1000))))
    return atk, dec, sus, rel


# ------------------------------------------------------------ one patch
def settings(p):
    """Patch settings and every effect's parameters, defaults filled in.
    -> (patch settings, {effect id: params} for the effects that are on, {effect id: chips})"""
    ps = {q["id"]: q["default"] for q in DEF["patch"]}
    ps.update({k: v for k, v in p.items() if k in ps})
    on, chips = {}, {}
    fx = p.get("fx", {})
    for e in DEF["effects"]:
        if e["id"] in fx or e.get("alwaysOn"):
            given = dict(fx.get(e["id"], {}))
            chips[e["id"]] = set(given.pop("on", e.get("chips", ["sid", "gb", "nes"])))
            vals = {q["id"]: q["default"] for q in e["params"]}
            for k in given:
                assert k in vals, f"{p['name']}: {e['id']} has no '{k}'"
            vals.update(given)
            on[e["id"]] = vals
    for k in p:
        assert k in ps or k == "fx", f"{p['name']}: unknown setting '{k}'"
    return ps, on, chips


def fields(p):
    ps, on, chips = settings(p)
    f = {}

    def has(eid, chip):
        return eid in on and chip in chips[eid]

    tone, env = on["tone"], on["env"]
    f["sndMono"] = ps["mono"]
    rp = on.get("repeat")
    f["sndRp"] = 1 if rp else 0
    f["sndRpTime"] = REPEAT_NATIVE[rp["time"]] if rp else 1
    f["sndRpCount"] = (rp["repeats"] if rp else 3) - 1
    f["sndRpLevel"] = max(0, min(5, round((100 - (rp["level"] if rp else 70)) / 10)))
    f["sndFat"] = ps["fatBass"]
    # ---- SID
    sus = env["sustain"]
    f["sndAD"] = nearest(SID_ATK, env["attack"]) << 4 | nearest(SID_DR, env["decay"])
    f["sndSR"] = sus << 4 | nearest(SID_DR, env["release"])
    f["sndWave"] = SID_WAVES[tone["sidWave"]]
    f["sndPwLo"] = tone["sidPw"] & 255
    f["sndPwHi"] = tone["sidPw"] >> 8
    f["sndPwVoice"] = tone["sidPwSpread"]
    det = on["detune"]["cents"] if "detune" in on else 0
    f["sndDet"] = round(det * 8 / 7) if has("detune", "sid") or has("detune", "nes") else 0
    f["sndOct"] = ps["octSid"] * 12 & 255
    gl = on.get("glide")
    f["sndGlide"] = gl["time"] + 3 if gl and (has("glide", "sid") or has("glide", "nes")) else 0
    fl = on.get("filter")
    f["sndCut"] = fl["cutoff"] if fl else 0
    f["sndRes"] = (fl["resonance"] << 4 | 7) if fl else 0
    f["sndFDep"] = fl["lfoDepth"] if fl else 0
    r = inc4(fl["filtLfoRate"]) if fl and fl["lfoDepth"] else 0
    f["sndFRateL"], f["sndFRateH"] = r & 255, r >> 8
    f["sndFEnv"] = max(0, fl["envAmount"]) if fl else 0
    pw = on.get("pwm") if has("pwm", "sid") else None
    f["sndPwm"] = round(pw["depth"] * 1.27) if pw else 0
    r = inc4(pw["pwmRate"]) if pw else 0
    f["sndPwmRL"], f["sndPwmRH"] = r & 255, r >> 8
    v = on.get("vibrato") if (has("vibrato", "sid") or has("vibrato", "nes")) else None
    f["sndVib"] = min(127, round(v["depth"] / 100 * 0.0595 * 4096)) if v else 0
    r = inc4(v["vibRate"]) if v else 0
    f["sndVibRL"], f["sndVibRH"] = r & 255, r >> 8
    f["sndVibDel"] = min(255, round(v["delay"] / 4)) if v else 0
    f["sndVibSpr"] = 1 if v and v["drift"] > 0 else 0         # until DRIFT is in: each voice its own phase
    ds = on.get("dutyseq")
    f["sndSeq"] = ds["pattern"] + 1 if ds else 0
    f["sndSeqMs"] = min(255, ds["stepMs"] // 4) if ds else 0
    f["sndSeqSid"] = 1 if ds and "sid" in chips["dutyseq"] else 0
    # ---- Game Boy (CC values)
    lvl = ps["lvlGbPulse"]
    if env["gbEnv"]:
        ga, gd, gs, gr = env["gbAttack"], env["gbDecay"], env["gbSustain"], env["gbRelease"]
    else:
        ga, gd, gs, gr = env["attack"], env["decay"], sus, env["release"]
    f["gbAtk"] = cc(gb_env_n(ga, lvl), 7)
    f["gbDec"] = cc(0 if gs >= 8 else gb_env_n(gd, lvl), 7)     # no sustain level yet: hold, or fall away
    f["gbRel"] = cc(gb_env_n(gr, lvl), 7)
    f["gbDuty1"] = cc(tone["gbDuty1"], 3)
    f["gbDuty2"] = cc(tone["gbDuty2"], 3)
    g = gb_glide(DEF_GLIDE_MS[gl["time"]]) if gl and has("glide", "gb") else 0
    f["gbGl1"] = f["gbGl2"] = f["gbGlW"] = cc(g, 15)
    mode = tone["gbWaveMode"]
    f["gbWMode"] = cc(mode, 6)
    f["gbWShape"] = 64 if mode == 1 else 0 if mode == 2 else cc(tone["gbWaveShape"], 15)
    w = on.get("warble") if has("warble", "gb") else None
    f["gbWarb"] = math.ceil(w["amount"] * 2.56 - 1e-9) if w else 0
    f["gbWSpd"] = w["speed"] if w else 40
    # one LFO on the pulses: vibrato (pitch), else PWM (duty)
    vb = on.get("vibrato") if has("vibrato", "gb") else None
    pm = on.get("pwm") if has("pwm", "gb") else None
    if vb:
        lf = (0, GB_SHAPES[DEF["lists"]["shapes"][vb["shape"]]], nearest(GB_LFO_HZ, vb["vibRate"]),
              gb_depth(vb["depth"]), min(15, round(vb["delay"] / (8000 / GB_TICK_HZ))))
    elif pm:
        lf = (1, GB_SHAPES[DEF["lists"]["shapes"][pm["shape"]]], nearest(GB_LFO_HZ, pm["pwmRate"]),
              round(pm["depth"] * 31 / 100), 0)
    else:
        lf = None
    f["gbLDest"] = cc(lf[0], 2) if lf else 0
    f["gbLShape"] = cc(lf[1], 4) if lf else 0
    f["gbLRate"] = cc(lf[2], 31) if lf else 0
    f["gbLDepth"] = cc(lf[3], 31) if lf else 0
    f["gbLDelay"] = cc(lf[4], 15) if lf else 0
    steps = round((det if has("detune", "gb") else 0) / 1.5625)
    f["gbDetA"] = max(0, (32 - steps) * 2)
    f["gbDetB"] = min(127, (32 + steps) * 2)
    f["gbLvl"] = cc(lvl, 15)
    f["gbLvlW"] = cc(ps["lvlGbWave"], 15)
    f["gbOct"] = ps["octGb"] * 12 & 255
    # ---- MidiNES (the C64's software envelope)
    peak = ps["lvlNes"]
    if env["nesEnv"]:
        na, nd, ns, nr = env["nesAttack"], env["nesDecay"], env["nesSustain"], env["nesRelease"]
    else:
        na, nd, ns, nr = env["attack"], env["decay"], sus, env["release"]
    flat = na <= 2 and ns == 15 and nr <= 6
    f["nesEnv"] = 0 if flat else 1
    a, d, s, r = nes_env(na / 1000, nd / 1000 * ns_scale(ns), ns / 15, nr / 1000, peak)
    f["nesAtk"], f["nesDec"] = (0, 0) if flat else (a, d)
    f["nesSus"] = 15 if flat else s
    f["nesPeak"] = peak
    f["nesRel"] = 0 if flat else r
    f["nesDuty1"] = tone["nesDuty1"] * 32
    f["nesDuty2"] = tone["nesDuty2"] * 32
    t = on.get("tremolo") if has("tremolo", "nes") else None
    f["nesTrem"] = round(t["depth"] * 15 / 100) if t else 0
    r = int(round(t["tremRate"] * 65536 / 100)) if t else 0      # per 10 ms
    f["nesTremRL"], f["nesTremRH"] = r & 255, r >> 8
    f["nesTremSq"] = 1 if t and DEF["lists"]["shapes"][t["shape"]] == "SQUARE" else 0
    return f


def ns_scale(ns):
    """The SID's decay time is for the whole way down; the NES's for peak -> sustain."""
    return 1 - ns / 15


DEF_GLIDE_MS = [int(v.split()[0]) for v in next(q for q in EFFECTS["glide"]["params"] if q["id"] == "time")["values"]]


# ------------------------------------------------------------ output
def build():
    rows = [fields(p) for p in PATCHES]
    names = list(rows[0])
    size = len(names) + NAME_LEN + 1
    out = ["; Generated by tools/gen_patches.py from patch/patches.json - do not edit.",
           "; The built-in patches (V), in order:"]
    for i, p in enumerate(PATCHES):
        out.append(f";  {i:2d} {p['name']}")
    out.append(f"NUM_SOUNDS  equ {len(PATCHES)}")
    out.append(f"PATCH_SIZE  equ {size}")
    out.append("  if PATCH_SIZE > 128\n    err\n  endif")
    out.append("; the live patch's fields")
    for k, name in enumerate(names):
        out.append(f"{name:12s}equ livePatch+{k}")
    out.append(f"{'patchName':12s}equ livePatch+{len(names)}")
    out.append("patchLo:    .byte " + ",".join(f"<patch{i}" for i in range(len(PATCHES))))
    out.append("patchHi:    .byte " + ",".join(f">patch{i}" for i in range(len(PATCHES))))
    for i, p in enumerate(PATCHES):
        assert len(p["name"]) <= NAME_LEN, p["name"]
        out.append(f"patch{i}:" + " " * (4 - len(str(i))) + ".byte " + ",".join(f"${rows[i][n] & 255:02X}" for n in names))
        out.append(f'        .byte "{p["name"]:{NAME_LEN}s}",0')
    open(os.path.join(ROOT, "src", "soundtab.asm"), "w").write("\n".join(out) + "\n")
    # for Chip Lab: the live patch's layout and the bytes of each built-in patch
    lay = {"format": "fat-chip-64-layout", "doc": "Fat Chip 64's live patch: these fields in this order, then the name "
           f"({NAME_LEN} characters and a 0). Sent as SysEx: F0 {' '.join(f'{b:02X}' for b in SYSEX_HEAD)} PATCH_SIZE, then each "
           "byte as two 4-bit halves (high first), then F7. Generated by tools/gen_patches.py.",
           "patchSize": size, "nameLen": NAME_LEN, "sysexHead": SYSEX_HEAD, "fields": names,
           "builtIn": {p["name"]: [rows[i][n] & 255 for n in names] for i, p in enumerate(PATCHES)}}
    with open(os.path.join(ROOT, "patch", "c64-layout.json"), "w") as f:
        f.write(json.dumps(lay, indent=1).replace("\n  ", " ").replace("\n ]", " ]"))
    return rows, names


SYSEX_HEAD = [0x7D, 0x46, 0x43, 0x01]       # non-commercial ID, "FC", 1 = a patch


def patch_bytes(p):
    """A patch (as in patches.json) -> its PATCH_SIZE bytes for Fat Chip 64."""
    f = fields(p)
    name = p["name"].upper()[:NAME_LEN].ljust(NAME_LEN)
    return [f[n] & 255 for n in f] + [ord(ch) for ch in name] + [0]


def sysex(p):
    b = patch_bytes(p)
    return [0xF0] + SYSEX_HEAD + [len(b)] + [x for v in b for x in (v >> 4, v & 15)] + [0xF7]


def read_old(path):
    """An older soundtab.asm (v0.18's layout) -> [ {field: byte} ]"""
    lines = open(path).read().split("\n")
    names = [l.split()[0] for l in lines if "equ livePatch+" in l and not l.startswith("patchName")]
    rows = []
    for l in lines:
        if l.startswith("patch") and ".byte $" in l:
            vals = [int(x.strip()[1:], 16) for x in l.split(".byte")[1].split(",")]
            rows.append(dict(zip(names, vals)))
    return rows


if __name__ == "__main__":
    rows, names = build()
    print(len(rows), "patches")
    if "--diff" in sys.argv:
        old = read_old(sys.argv[sys.argv.index("--diff") + 1])
        for i, (a, b) in enumerate(zip(old, rows)):
            d = [f"{n} {a.get(n, 0):02X}>{b[n] & 255:02X}" for n in names if a.get(n, 0) != b[n] & 255]
            print(f"{i:2d} {PATCHES[i]['name']:16s} " + (", ".join(d) if d else "same"))
