#!/usr/bin/env python3
"""Fat Chip 64's menu: the pages and their lines -> src/menutab.asm.

Three kinds of line:
  page    RETURN opens another page
  enum    a variable stepping through values (CRSR RIGHT / SHIFT+CRSR RIGHT)
  effect  a patch effect: CRSR RIGHT on / off, RETURN opens its settings
  param   one setting of the live patch, stepping through ready-made values

The patch settings (effect and param lines) can't run gen_patches' maths on
the C64, so each setting gets a list of steps here, and for each step the
live patch bytes it writes (worked out with gen_patches.fields, the other
settings at their defaults). The C64 finds where a patch is by comparing one
"key" byte with each step's. The envelope is special: its four settings write
the SID's nibbles, and the C64 works out the Game Boy and NES envelope from
tables made here (EnvDerive).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_patches as G  # noqa: E402

ROOT = os.path.join(HERE, "..")
DEF = G.DEF
LAYOUT = json.load(open(os.path.join(ROOT, "patch", "c64-layout.json")))
FIELDS = LAYOUT["fields"]
FI = {n: i for i, n in enumerate(FIELDS)}
EFF = {e["id"]: e for e in DEF["effects"]}
LFO = ["gbLDest", "gbLShape", "gbLRate", "gbLDepth", "gbLDelay"]
LBL = 10                                   # value labels: 10 characters

# ------------------------------------------------------------ the patch settings on the C64
# effect id -> [(param id, steps)]; steps = values in the definition's units
SHAPES = list(range(6))
STEPS = {
    "patch": [("mono", [0, 1]), ("fatBass", [0, 1])],
    "tone": [("sidWave", list(range(8))), ("sidPw", [256, 512, 768, 1024, 1536, 2048, 2560, 3072, 3584, 3840]),
             ("sidPwSpread", [0, 1]), ("gbDuty1", [0, 1, 2, 3]), ("gbDuty2", [0, 1, 2, 3]),
             ("gbWaveMode", [0, 1, 2, 3]), ("gbWaveShape", list(range(16))), ("nesDuty1", [0, 1, 2, 3]), ("nesDuty2", [0, 1, 2, 3])],
    "env": [("attack", None), ("decay", None), ("sustain", list(range(16))), ("release", None)],
    "detune": [("cents", [0, 2, 3, 4, 5, 7, 10, 14, 20, 25, 30, 40, 50])],
    "vibrato": [("depth", [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]), ("vibRate", [1, 2, 3, 4, 4.5, 5, 5.5, 6, 6.5, 7, 8, 10, 12]),
                ("delay", [0, 100, 200, 300, 400, 600, 800, 1000, 1500, 2000]), ("shape", SHAPES), ("drift", [0, 50])],
    "glide": [("time", [0, 1, 2, 3, 4])],
    "warble": [("amount", [2, 4, 6, 8, 10, 12, 16, 20, 25, 30, 40, 50]), ("speed", [10, 20, 30, 40, 50, 60, 80, 100, 127])],
    "tremolo": [("depth", [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]), ("tremRate", [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 16]), ("shape", SHAPES)],
    "filter": [("cutoff", [8, 16, 24, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 255]), ("resonance", list(range(16))),
               ("envAmount", [0, 16, 32, 48, 64, 96, 127]), ("lfoDepth", [0, 8, 16, 24, 32, 48, 64, 96, 127]),
               ("filtLfoRate", [0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6])],
    "pwm": [("depth", [10, 20, 30, 40, 50, 60, 70, 80, 90]), ("pwmRate", [0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2, 3, 4]), ("shape", SHAPES)],
    "dutyseq": [("pattern", [0, 1]), ("stepMs", [20, 30, 40, 60, 80, 120, 160, 250, 333, 500])],
    "repeat": [("time", [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14]), ("repeats", list(range(1, 9))), ("level", [50, 60, 70, 80, 90, 100])],
}
FX_ORDER = ["patch", "tone", "env", "detune", "vibrato", "glide", "warble", "tremolo", "filter", "pwm", "dutyseq", "repeat"]
ALWAYS = {"patch", "tone", "env"}
DICE = ["detune", "glide", "warble", "filter", "pwm", "tremolo", "vibrato"]       # pwm before vibrato
SHORT = {"PULSE+SAW+TRI": "P+S+T", "PULSE+TRI": "PULS+TRI", "PULSE+SAW": "PULS+SAW", "50/25/12.5%": "SPREAD"}
FXNAME = {"patch": "PATCH", "tone": "TONE", "env": "ENVELOPE", "dutyseq": "DUTY STEPS"}
PNAME = {("patch", "mono"): "MONO", ("patch", "fatBass"): "FAT BASS", ("vibrato", "vibRate"): "RATE",
         ("tremolo", "tremRate"): "RATE", ("pwm", "pwmRate"): "RATE", ("filter", "filtLfoRate"): "LFO RATE",
         ("tone", "gbWaveShape"): "GB WAVE SHAPE", ("tone", "sidPwSpread"): "SID WIDTHS"}


def qdef(eid, pid):
    if eid == "patch":
        return next(q for q in DEF["patch"] if q["id"] == pid)
    return next(q for q in EFF[eid]["params"] if q["id"] == pid)


def label(eid, pid, v):
    q = qdef(eid, pid)
    if pid in ("mono",):
        s = ["POLY", "MONO"][v]
    elif pid == "fatBass":
        s = ["OFF", "ON"][v]
    elif q["type"] == "enum":
        s = SHORT.get(q["values"][v], q["values"][v])
    elif q["type"] == "ms" or pid in ("delay", "stepMs"):
        s = (f"{v / 1000:g} S" if v >= 1000 else f"{v} MS") if v else "NONE" if pid == "delay" else f"{v} MS"
    elif q["type"] == "hz":
        s = f"{v:g} HZ"
    elif pid == "sidPw":
        s = f"{round(v * 100 / 4096)} %"
    elif q.get("unit") == "cents" or pid in ("cents",) or (eid in ("vibrato", "warble") and pid in ("depth", "amount")):
        s = f"{v} CENTS"
    elif q.get("unit") == "%" or pid in ("level", "drift") or (eid in ("tremolo", "pwm") and pid == "depth"):
        s = f"{v} %"
    else:
        s = str(v)
    s = s.upper()
    assert len(s) <= LBL, (eid, pid, s)
    return s


def base_patch(eid=None, vals=None):
    """a patch with the defaults, effect eid on with vals"""
    p = {"name": "X", "fx": {}}
    if eid and eid not in ("patch", "tone", "env"):
        p["fx"][eid] = dict(vals or {})
    elif eid in ("tone", "env"):
        p["fx"][eid] = dict(vals or {})
    elif eid == "patch":
        p.update(vals or {})
    return p


def build_params():
    params, effects = [], []
    off_base = G.fields(base_patch())
    for eid in FX_ORDER:
        e0 = len(params)
        plist = STEPS[eid]
        all_vary = set()
        for pid, steps in plist:
            q = qdef(eid, pid)
            if steps is None:                       # the envelope's times: the SID's 16
                steps = q["values"]
            ctx = {("tone", "gbWaveShape"): {"gbWaveMode": 0}, ("filter", "filtLfoRate"): {"lfoDepth": 32}}.get((eid, pid), {})
            rows = [G.fields(base_patch(eid, {**ctx, pid: v})) for v in steps]
            if eid == "env":
                fld, mask = {"attack": ("sndAD", 0xF0), "decay": ("sndAD", 0x0F),
                             "sustain": ("sndSR", 0xF0), "release": ("sndSR", 0x0F)}[pid]
                writes = [[(FI[fld], mask, r[fld] & mask)] for r in rows]
                key = (FI[fld], 0xFF, mask)
                vary = [fld]
            else:
                vary = [n for n in FIELDS if len({r[n] & 255 for r in rows}) > 1]
                assert vary, (eid, pid)
                if eid == "pwm":
                    pass                                # (LFO fields: written only by LfoFix)
                writes = [[(FI[n], 0xFF, r[n] & 255) for n in vary] for r in rows]
                k = vary[0]
                partner = None
                for a, b in (("L", "H"), ("Lo", "Hi")):
                    if k.endswith(a) and k[:-len(a)] + b in vary:
                        partner = k[:-len(a)] + b
                key = (FI[k], FI[partner] if partner else 0xFF, 0xFF)
            all_vary |= set(vary)
            keyvals = []
            for r in rows:
                if eid == "env":
                    keyvals.append(r[FIELDS[key[0]]] & key[2])
                else:
                    lo = r[FIELDS[key[0]]] & 255
                    hi = r[FIELDS[key[1]]] & 255 if key[1] != 0xFF else 0
                    keyvals.append(hi << 8 | lo)
            dv = q["default"]
            default = min(range(len(steps)), key=lambda i: abs((steps[i] if not isinstance(steps[i], str) else 0) - dv)) \
                if not isinstance(dv, list) else 0
            rlo, rhi = 0, len(steps) - 1
            if "rand" in q and q["type"] != "enum":
                lo_, hi_ = q["rand"]
                ins = [i for i, v in enumerate(steps) if lo_ <= v <= hi_]
                if ins:
                    rlo, rhi = ins[0], ins[-1]
            elif "rand" in q:
                rlo, rhi = q["rand"][0], min(q["rand"][1], len(steps) - 1)
            flags = (1 if eid == "env" else 0) | (2 if eid == "patch" else 0)
            params.append(dict(eid=eid, pid=pid, name=PNAME.get((eid, pid), q["name"]), steps=steps,
                               labels=[label(eid, pid, v) for v in steps], writes=writes, key=key, keyvals=keyvals,
                               default=default, rlo=rlo, rhi=rhi, flags=flags))
        # the effect: off row (its fields as with it off, not the GB LFO), on row
        if eid in ALWAYS:
            effects.append(dict(eid=eid, p0=e0, np=len(params) - e0, off=[], det=0, on=[], prob=0, dice=0, always=1))
            continue
        on_default = G.fields(base_patch(eid, {}))
        on_only = [n for n in FIELDS if on_default[n] != off_base[n] and n not in all_vary]
        offf = [n for n in FIELDS if n in all_vary or n in on_only]
        offf = [n for n in offf if n not in LFO]
        on_row = [(FI[n], on_default[n] & 255) for n in on_only if n not in LFO]
        if eid == "vibrato":
            on_row.append((FI["gbLDest"], 0))
        if eid == "pwm":
            on_row.append((FI["gbLDest"], G.cc(1, 2)))
        effects.append(dict(eid=eid, p0=e0, np=len(params) - e0, off=[(FI[n], off_base[n] & 255) for n in offf],
                            det=len(offf), on=on_row, prob=round(EFF[eid].get("randOn", 0.3) * 128),
                            dice=1 if eid in DICE else 0, always=0))
    return params, effects


def env_tables():
    """the Game Boy and NES envelope from the SID's four nibbles (levels 15)"""
    A, D = DEF["lists"]["sidAttackMs"], DEF["lists"]["sidDecayReleaseMs"]
    lvl, peak = 15, 15
    gbA = [G.cc(G.gb_env_n(A[i], lvl), 7) for i in range(16)]
    gbD = [G.cc(G.gb_env_n(D[i], lvl), 7) for i in range(16)]
    gbR = [G.cc(G.gb_env_n(D[i], lvl), 7) for i in range(16)]
    nA = [G.nes_env(A[i] / 1000, 0, 1, 0, peak)[0] for i in range(16)]
    nR = [G.nes_env(0, 0, 1, D[i] / 1000, peak)[3] for i in range(16)]
    nS = [G.nes_env(0, 0, s / 15, 0, peak)[2] for s in range(16)]
    nD = [G.nes_env(0, D[d] / 1000 * (1 - s / 15), s / 15, 0, peak)[1] for s in range(16) for d in range(16)]
    return gbA, gbD, gbR, nA, nR, nS, nD


# ------------------------------------------------------------ the pages
ACTS = ["MUTE", "BEND DOWN", "BEND UP", "VIBRATO", "TREMOLO", "ARP", "STUTTER", "VINYL STOP", "GLIDE", "SUSTAIN",
        "OCTAVE UP", "REPEAT", "FILTER SWEEP", "BEAT FILL", "TAPE WOBBLE", "WIDE", "TAP TEMPO", "BEAT ON/OFF",
        "NEXT SOUND", "NOTHING"]
BREATH_FX = ["NONE", "VIBRATO DEPTH", "WARBLE DEPTH", "DETUNE DEPTH", "FILTER"] + ["HELD: " + a for a in ACTS[:-1]]


def enum(lbl, var, values, hook=None, show=None):
    return dict(kind=1, lbl=lbl, var=var, values=values, hook=hook, show=show)


def page(lbl, target, show=None):
    return dict(kind=0, lbl=lbl, target=target, show=show)


PAGES = []


def add_page(name, title, header, items, parent=None):
    PAGES.append(dict(name=name, title=title, header=header, items=items, parent=parent))


def build_pages(params, effects):
    add_page("main", "FAT CHIP 64 MENU", None, [
        enum("SID", "devOn", ["OFF", "ON"], hook="DevHook"),
        enum("GAME BOY", "devOn+1", ["OFF", "ON"], hook="DevHook"),
        enum("MIDINES", "devOn+2", ["OFF", "ON"], hook="DevHook"),
        None,
        page("PATCH", "patch"),
        page("PLAYING", "playing"),
        page("DEVICES", "devices"),
        None,
        page("YAMAHA SHS-10", "shs", show="useShs"),
        page("CASIO DH-100", "dh", show="useDh"),
        page("ATARI SYNTHCART", "sc", show="useSc"),
    ])
    pl = []
    for e in effects:
        if e["eid"] == "patch":
            pl += [dict(kind=3, lbl=params[e["p0"] + i]["name"], param=e["p0"] + i) for i in range(e["np"])]
        else:
            pl.append(dict(kind=2, lbl=FXNAME.get(e["eid"], EFF[e["eid"]]["name"]), fx=effects.index(e)))
    add_page("patch", "PATCH", "@NAME", pl, parent="main")
    for e in effects:
        if e["eid"] == "patch":
            continue
        items = [dict(kind=3, lbl=params[e["p0"] + i]["name"], param=e["p0"] + i) for i in range(e["np"])]
        add_page("fx_" + e["eid"], FXNAME.get(e["eid"], EFF[e["eid"]]["name"]), "@NAME", items, parent="patch")
    add_page("playing", "PLAYING", None, [
        enum("LATCH STYLE (C= L)", "latchStyle", ["SMART", "HOLD", "ADD"], hook="LatchStyleHook"),
        enum("SPACE", "spaceAct", ACTS, hook="SpaceHook"),
        enum("BEND RANGE", "bendRange", [f"{i} SEMITONE" + ("S" if i > 1 else "") for i in range(1, 25)]),
        enum("BEAT TEMPO", "beatTempo", ["DEFAULT", "IGNORE"]),
    ], parent="main")
    add_page("devices", "DEVICES", "WHAT'S PLUGGED IN", [
        enum("YAMAHA SHS-10", "useShs", ["NOT USED", "IN USE"], hook="UseHook"),
        enum("CASIO DH-100", "useDh", ["NOT USED", "IN USE"], hook="UseHook"),
        enum("ATARI SYNTHCART", "useSc", ["NOT USED", "IN USE"], hook="UseHook"),
    ], parent="main")
    add_page("shs", "YAMAHA SHS-10", "MIDI IN", [
        enum("TEMPO", "shsTempo", ["FOLLOW", "IGNORE"], hook="SyncDerive"),
        enum("SHS-10 RHYTHM", "shsRhythm", ["IGNORE", "PLAY ON MIDINES"], hook="SyncDerive"),
        enum("START/STOP", "shsStart", ["BUILT-IN BEATS", "IGNORE"], hook="SyncDerive"),
        enum("VOICE BUTTONS", "syncVoice", ["PICK PATCH", "IGNORE"]),
        enum("RHYTHM BUTTONS", "syncRhythm", ["PICK BEAT", "IGNORE"]),
        enum("WHEEL", "syncWheel", ["BEND", "OFF"], hook="WheelHook"),
        enum("VIBRATO BUTTON", "btnTask", ACTS),
        enum("PORTAMENTO BUTTON", "btnTask+1", ACTS),
        enum("SUSTAIN BUTTON", "btnTask+2", ACTS),
    ], parent="main")
    add_page("dh", "CASIO DH-100", "MIDI IN: BREATH, BUTTONS", [
        enum("BREATH", "dhBreath", ["VOLUME", "VOLUME+FILTER", "FILTER", "OFF"], hook="BreathFxHook"),
        enum("BREATH FX1", "dhFx1", BREATH_FX, hook="BreathFxHook"),
        enum("BREATH FX2", "dhFx2", BREATH_FX, hook="BreathFxHook"),
        enum("BREATH FEEL", "dhFeel", ["SOFT", "NORMAL", "HARD"]),
        enum("NOTES", "dhNotes", ["AS PLAYED", "CHORD", "HARMONY"], hook="DhNotesHook"),
        enum("PORTAMENTO BUTTON", "dhPort", ACTS),
        enum("TONE BUTTONS", "dhTone", ["PICK BANK", "IGNORE"]),
    ], parent="main")
    add_page("sc", "ATARI SYNTHCART", "TEMPO: , . NUDGE, SHIFT , . STEP", [
        enum("TEMPO", "scSync", ["OFF", "SYNC"], hook="SyncDerive"),
        enum("TRIM", "scTrim", [f"{v:+d}" if v else "0" for v in range(-8, 9)], hook="TempoHook"),
        None,
        enum("TUNE TO", "scSound", ["OFF", "SQUARE C -10", "LEAD F -10", "BASS C# -35", "PITFALL C# -30", "SAW C# +10"],
             hook="SyncDerive"),
        enum("MATCH KEY", "scKey", ["OFF", "ON"], hook="SyncDerive"),
    ], parent="main")


def strings_of(items):
    return items


def main():
    params, effects = build_params()
    build_pages(params, effects)
    pnum = {p["name"]: i for i, p in enumerate(PAGES)}
    items, item_page = [], []
    for pi, pg in enumerate(PAGES):
        pg["first"] = len(items)
        row = 3 if pg["header"] else 2
        for it in pg["items"]:
            if it is None:
                row += 1
                continue
            it = dict(it)
            it["row"] = row
            row += 1
            items.append(it)
            item_page.append(pi)
        pg["count"] = len(items) - pg["first"]
        assert row <= 21, (pg["name"], row)
    # parents: the item on the parent page that opens this page
    for pi, pg in enumerate(PAGES):
        pg["back"] = 0
        pg["backItem"] = 0
        if pg["parent"]:
            par = pnum[pg["parent"]]
            pg["back"] = par
            for i in range(PAGES[par]["first"], PAGES[par]["first"] + PAGES[par]["count"]):
                it = items[i]
                if (it["kind"] == 0 and pnum[it["target"]] == pi) or \
                   (it["kind"] == 2 and pnum.get("fx_" + effects[it["fx"]]["eid"]) == pi):
                    pg["backItem"] = i
    out = ["; Generated by tools/gen_menu.py - do not edit."]
    A = out.append
    A(f"MENU_ITEMS  equ {len(items)}")
    A(f"NUM_PAGES   equ {len(PAGES)}")
    A(f"NUM_PARAMS  equ {len(params)}")
    A(f"NUM_FX      equ {len(effects)}")
    A(f"FX_VIB      equ {[e['eid'] for e in effects].index('vibrato')}")
    A(f"FX_PWM      equ {[e['eid'] for e in effects].index('pwm')}")
    A(f"PG_PATCH    equ {pnum['patch']}")
    for n in ["gbAtk", "gbDec", "gbRel", "nesEnv", "nesAtk", "nesDec", "nesSus", "nesRel", "sndAD", "sndSR"] + LFO:
        A(f"FLD_{n:10s}equ {FI[n]}")
    # ---- items
    def lo_hi(name, vals):
        A(f"{name}Lo: .byte " + ",".join(f"<({v})" for v in vals))
        A(f"{name}Hi: .byte " + ",".join(f">({v})" for v in vals))
    kinds, args, counts, vlo, hooks, lbls, shows, rows = [], [], [], [], [], [], [], []
    for i, it in enumerate(items):
        kinds.append(it["kind"])
        rows.append(it["row"])
        lbls.append(f"mL{i}")
        shows.append(it.get("show") or "0")
        hooks.append(it.get("hook") or "0")
        if it["kind"] == 0:
            args.append(str(pnum[it["target"]])); counts.append(0); vlo.append("0")
        elif it["kind"] == 1:
            args.append(it["var"]); counts.append(len(it["values"])); vlo.append(f"mE{i}")
        elif it["kind"] == 2:
            args.append(str(it["fx"])); counts.append(0); vlo.append("0")
        else:
            args.append(str(it["param"])); counts.append(0); vlo.append("0")
    A("mKind:      .byte " + ",".join(map(str, kinds)))
    A("mRowY:      .byte " + ",".join(map(str, rows)))
    A("mCount:     .byte " + ",".join(map(str, counts)))
    lo_hi("mArg", args)
    lo_hi("mVal", vlo)
    lo_hi("mHook", hooks)
    lo_hi("mLbl", lbls)
    lo_hi("mShow", shows)
    pool = {}

    def sref(v):
        if v not in pool:
            pool[v] = f"mS{len(pool)}"
        return pool[v]
    lists = {}
    for i, it in enumerate(items):
        A(f'mL{i}:      .byte "{it["lbl"]} ",0')
        if it["kind"] == 1:
            key = tuple(it["values"])
            if key in lists:
                A(f"mE{i}      equ {lists[key]}")
            else:
                lists[key] = f"mE{i}"
                A(f"mE{i}:      .word " + ",".join(sref(v[:16]) for v in it["values"]))
    for v, n in pool.items():
        A(f'{n}:   .byte "{v}",0')
    # ---- pages
    A("pgFirst:    .byte " + ",".join(str(p["first"]) for p in PAGES))
    A("pgCount:    .byte " + ",".join(str(p["count"]) for p in PAGES))
    A("pgBack:     .byte " + ",".join(str(p["back"]) for p in PAGES))
    A("pgBackItem: .byte " + ",".join(str(p["backItem"]) for p in PAGES))
    A("pgFx:       .byte " + ",".join(str(next((k for k, e in enumerate(effects) if "fx_" + e["eid"] == p["name"]), 255)) for p in PAGES))
    A("efPage:     .byte " + ",".join(str(next((k for k, p in enumerate(PAGES) if p["name"] == "fx_" + e["eid"]), 255)) for e in effects))
    lo_hi("pgTitle", [f"pgT{i}" for i in range(len(PAGES))])
    lo_hi("pgHdr", [("pgH%d" % i) if p["header"] and p["header"] != "@NAME" else ("patchName" if p["header"] else "0") for i, p in enumerate(PAGES)])
    for i, p in enumerate(PAGES):
        A(f'pgT{i}:      .byte "{p['title'][:19]}",0')
        if p["header"] and p["header"] != "@NAME":
            A(f'pgH{i}:      .byte "{p["header"][:40]}",0')
    # ---- patch settings
    A("; the patch settings: per param its effect, steps, default, dice range, key, writes")
    A("prFx:       .byte " + ",".join(str([e["eid"] for e in effects].index(p["eid"])) for p in params))
    A("prN:        .byte " + ",".join(str(len(p["steps"])) for p in params))
    A("prDef:      .byte " + ",".join(str(p["default"]) for p in params))
    A("prRLo:      .byte " + ",".join(str(p["rlo"]) for p in params))
    A("prRHi:      .byte " + ",".join(str(p["rhi"]) for p in params))
    A("prKey:      .byte " + ",".join(str(p["key"][0]) for p in params))
    A("prKeyH:     .byte " + ",".join(str(p["key"][1]) for p in params))
    A("prKeyM:     .byte " + ",".join(str(p["key"][2]) for p in params))
    A("prNW:       .byte " + ",".join(str(len(p["writes"][0])) for p in params))
    A("prFlags:    .byte " + ",".join(str(p["flags"]) for p in params))
    lo_hi("prW", [f"pW{i}" for i in range(len(params))])
    lo_hi("prK", [f"pK{i}" for i in range(len(params))])
    lo_hi("prL", [f"pS{i}" for i in range(len(params))])
    A("prLW:       .byte " + ",".join(str(max(len(x) for x in p["labels"]) + 1) for p in params))
    for i, p in enumerate(params):
        A(f"pW{i}:  .byte " + ",".join(f"{f},${m:02X},${v:02X}" for row in p["writes"] for f, m, v in row))
        A(f"pK{i}:  .word " + ",".join(str(k) for k in p["keyvals"]))
        w = max(len(x) for x in p["labels"])
        A(f"pS{i}:  .byte " + ",".join(f'"{x:{w}s}",0' for x in p["labels"]))
    A("; the effects: params, off row (field, value), detection count, on row, dice")
    A("efP0:       .byte " + ",".join(str(e["p0"]) for e in effects))
    A("efNP:       .byte " + ",".join(str(e["np"]) for e in effects))
    A("efOffN:     .byte " + ",".join(str(len(e["off"])) for e in effects))
    A("efOnN:      .byte " + ",".join(str(len(e["on"])) for e in effects))
    A("efProb:     .byte " + ",".join(str(e["prob"]) for e in effects))
    A("efDice:     .byte " + ",".join(str(e["dice"]) for e in effects))
    A("efAlways:   .byte " + ",".join(str(e["always"]) for e in effects))
    lo_hi("efOff", [f"eO{i}" for i in range(len(effects))])
    lo_hi("efOn", [f"eN{i}" for i in range(len(effects))])
    for i, e in enumerate(effects):
        A(f"eO{i}:  .byte " + (",".join(f"{f},${v:02X}" for f, v in e["off"]) or "0"))
        A(f"eN{i}:  .byte " + (",".join(f"{f},${v:02X}" for f, v in e["on"]) or "0"))
    A("; the envelope's Game Boy and NES parts from the SID's nibbles (EnvDerive)")
    gbA, gbD, gbR, nA, nR, nS, nD = env_tables()
    for name, t in (("edGbAtk", gbA), ("edGbDec", gbD), ("edGbRel", gbR), ("edNesAtk", nA), ("edNesRel", nR), ("edNesSus", nS), ("edNesDec", nD)):
        A(f"{name}: .byte " + ",".join(str(v) for v in t))
    open(os.path.join(ROOT, "src", "menutab.asm"), "w").write("\n".join(out) + "\n")
    print(f"{len(items)} menu lines on {len(PAGES)} pages, {len(params)} patch settings")


if __name__ == "__main__":
    main()
