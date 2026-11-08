#!/usr/bin/env python3
"""Fat Chip 64 sounds (V): one readable entry per sound -> src/soundtab.asm.

The first three are v0.11's FAT / PADS / RAW, unchanged. The rest are demo
versions of the Chip Lab sounds Reeve loved or liked (2026-11-06/07): close to
their character, without the per-patch parameters, jobs or blending yet.

Units:
  sid   wave tri/saw/pulse; ad, sr = the SID's registers; pw 0-4095;
        det = detune of SID 2 (+) and SID 3 (-) in 1/8 of a frequency step's
        high byte (8 = v0.11's FAT, about 7 cents); oct = semitones;
        glide = 0 off, else the fraction of the way per 4 ms (1/2^k);
        filt = (cutoff high byte, resonance 0-15, LFO depth, LFO Hz, env amount)
        pwm  = (depth: width + tri x depth / 8, Hz)
        vib  = (semitones, Hz, delay s, spread: each voice its own phase)
        duty = (sequence 1 or 2, ms per step): pulse width steps (also on the NES)
  gb    Fat Chip GB parameter values (its own ranges, sent as CCs): atk, dec, rel
        0-7, duty 0-3 per pulse, glide 0-15 (pulse 1, pulse 2, wave),
        wave = (mode, shape CC), warble / wspeed = CC 104 / 105 values,
        lfo = (dest 0 pitch / 1 duty, shape 0-4, rate 0-31, depth 0-31, delay 0-15),
        det = cents (pulse 1 -, pulse 2 +), lvl = pulses 0-15, lvlw = wave 0-15,
        oct = pulses play this many semitones up
  rep   REPEAT default: (time, repeats, level): time 0 1/4, 1 1/8 dotted,
        2 1/8, 3 1/8T, 4 1/16, 5-13 FREE 80/100/125/150/200/250/300/400/500
        ms; repeats 1-8; level 0 FULL, 1 90 %, 2 80 %, 3 70 %, 4 60 %, 5 50 %.
        Without it REPEAT starts off (1/8 dotted, 3, 70 % if turned on).
  nes   env = None (no envelope, full volume) or (attack s, decay s, sustain 0-1,
        release s); peak = loudest level 0-15; duty 0-3 per pulse;
        trem = (depth 0-15, Hz, square)
"""
import math
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")

WAVE_TRI = (2, 0)           # wave channel: plain triangle
WAVE_SQ = (1, 64)           # third pulse, 50%
WAVE_SAW = (0, 1)           # synth wave, shape 1 (SAW LP)
WAVE_ORGAN = (0, 5)         # synth wave, shape 5 (ORGAN)

SOUNDS = [
    # ------------------------------------------------ v0.11
    dict(name="FAT", mono=0, fb=1,
         sid=dict(wave="saw", ad=0x19, sr=0xC9, pw=0x800, det=8),
         gb=dict(atk=0, rel=2, duty=(2, 2), wave=WAVE_TRI, warble=24, det=5),
         nes=dict(env=None, duty=(2, 2))),
    dict(name="PADS", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0xA0, sr=0xFB, pw=0x300, det=8, filt=(0x10, 7, 96, 0.122, 0),
                  pwm=(64, 0.49)),
         gb=dict(atk=5, rel=6, duty=(2, 2), glide=(0, 8, 0), wave=WAVE_TRI, warble=48, det=5),
         nes=dict(env="pads", duty=(2, 2))),
    dict(name="RAW", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x00, sr=0xF0, pw=0x800, det=8),
         gb=dict(atk=0, rel=0, duty=(2, 1), wave=WAVE_SQ, warble=0, det=5),
         nes=dict(env=None, duty=(2, 1))),
    # ------------------------------------------------ Chip Lab: leads
    dict(name="DUTY LEAD", mono=1, fb=0,
         sid=dict(wave="pulse", ad=0x08, sr=0xC6, pw=0x400, det=8, duty=(1, 30)),
         gb=dict(atk=0, rel=1, duty=(1, 1), wave=WAVE_SQ, lvl=10, lvlw=12, det=5, lfo=(1, 0, 25, 10, 0)),
         nes=dict(env=(0, 0, 1, 0.1), peak=11, duty=(2, 2))),
    dict(name="WHISTLE", mono=1, fb=0,
         sid=dict(wave="tri", ad=0x38, sr=0xC7, det=4, glide=3, vib=(0.25, 4.5, 0.4, 0)),
         gb=dict(atk=0, rel=1, duty=(2, 2), glide=(2, 2, 2), wave=WAVE_TRI, lvl=3, lvlw=15, det=3,
                 lfo=(0, 0, 22, 5, 6)),
         nes=dict(env=(0.08, 0.2, 0.9, 0.2), peak=6, duty=(2, 2))),
    dict(name="SCREAMER", mono=1, fb=0,
         sid=dict(wave="saw", ad=0x07, sr=0xC6, det=9, filt=(0x14, 13, 0, 0, 0x40), vib=(0.35, 7, 0.15, 0)),
         gb=dict(atk=0, rel=1, duty=(1, 1), wave=WAVE_SAW, lvl=8, lvlw=12, det=8, lfo=(0, 0, 24, 6, 2)),
         nes=dict(env=(0, 0, 1, 0.1), peak=9, duty=(1, 1))),
    # ------------------------------------------------ pads
    dict(name="WARBLE PAD", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x8B, sr=0xEB, pw=0x800, det=11, vib=(0.2, 1.5, 0, 1)),
         gb=dict(atk=3, rel=4, duty=(2, 2), wave=WAVE_TRI, lvl=9, warble=100, wspeed=30, det=9),
         nes=dict(env=(0.6, 0.3, 1, 1), peak=8, duty=(2, 2))),
    dict(name="DUTY SHIMMER PAD", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x6A, sr=0xEA, pw=600, det=8, pwm=(88, 0.3)),
         gb=dict(atk=0, rel=2, duty=(1, 1), wave=WAVE_TRI, lvl=10, det=5, lfo=(1, 0, 10, 16, 0)),
         nes=dict(env=(0.05, 0, 1, 0.5), peak=9, duty=(0, 0), seq=(2, 333))),
    dict(name="WARM SID PAD", mono=0, fb=1,
         sid=dict(wave="saw", ad=0xAB, sr=0xEB, det=12, filt=(0x1C, 4, 0, 0, 0)),
         gb=dict(atk=4, rel=4, duty=(2, 2), wave=WAVE_TRI, lvl=6, lvlw=10, det=8),
         nes=dict(env=(1.2, 0.5, 0.9, 1), peak=7, duty=(2, 2))),
    dict(name="BREATHING PAD", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x9A, sr=0xDA, pw=0x800, det=6),
         gb=dict(atk=3, rel=4, duty=(2, 2), wave=WAVE_TRI, lvl=11, det=5),
         nes=dict(env=(0.6, 0.2, 1, 1), peak=11, duty=(1, 1), trem=(9, 0.45, 0))),
    # ------------------------------------------------ keys and organ
    dict(name="ELECTRIC PIANO", mono=0, fb=1,
         sid=dict(wave="tri", ad=0x0A, sr=0x69, det=5),
         gb=dict(atk=0, dec=3, rel=2, duty=(2, 2), wave=WAVE_TRI, lvl=8, det=4),
         nes=dict(env=(0, 0.8, 0.3, 0.5), peak=9, duty=(2, 2), trem=(8, 5, 0))),
    dict(name="COMBO ORGAN", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x00, sr=0xF1, pw=0x800, det=8, vib=(0.1, 7, 0, 0)),
         gb=dict(atk=0, rel=0, duty=(2, 2), wave=WAVE_ORGAN, lvl=10, det=5, lfo=(0, 0, 24, 4, 0)),
         nes=dict(env=(0, 0, 1, 0), peak=10, duty=(2, 2))),
    dict(name="VIBRAPHONE", mono=0, fb=0,
         sid=dict(wave="tri", ad=0x0B, sr=0x3B, det=4),
         gb=dict(atk=0, dec=5, rel=3, duty=(2, 2), wave=WAVE_TRI, lvl=5, det=3),
         nes=dict(env=(0, 1.2, 0.15, 0.8), peak=8, duty=(2, 2), trem=(8, 4.5, 0))),
    # ------------------------------------------------ bass and experimental
    dict(name="GLIDE BASS", mono=1, fb=1,
         sid=dict(wave="saw", ad=0x09, sr=0xB5, det=7, glide=4, filt=(0x1A, 7, 0, 0, 0)),
         gb=dict(atk=0, rel=1, duty=(1, 1), glide=(4, 4, 4), wave=WAVE_TRI, lvl=5, lvlw=15, det=4),
         nes=dict(env=(0, 0, 1, 0.1), peak=6, duty=(2, 2))),
    dict(name="WAVE BASS", mono=1, fb=1,
         sid=dict(wave="tri", ad=0x09, sr=0xC6, det=4),
         gb=dict(atk=0, rel=1, duty=(1, 1), wave=WAVE_TRI, lvl=4, lvlw=15, det=3),
         nes=dict(env=(0, 0, 1, 0.1), peak=6, duty=(2, 2))),
    dict(name="SEASICK CHORUS", mono=0, fb=1,
         sid=dict(wave="saw", ad=0x6A, sr=0xEA, det=16, vib=(0.3, 1.2, 0, 1)),
         gb=dict(atk=1, rel=4, duty=(2, 2), wave=WAVE_SAW, lvl=9, lvlw=12, warble=70, wspeed=25, det=14),
         nes=dict(env=(0.3, 0, 1, 1), peak=8, duty=(1, 1))),
    # ------------------------------------------------ REPEAT (v0.13)
    dict(name="REPEAT LEAD", mono=1, fb=0, rep=(2, 3, 0),
         sid=dict(wave="pulse", ad=0x08, sr=0xC6, pw=0x600, det=8, vib=(0.15, 5.5, 0.3, 0)),
         gb=dict(atk=0, rel=1, duty=(1, 1), wave=WAVE_SQ, lvl=11, lvlw=12, det=5),
         nes=dict(env=(0, 0, 1, 0.1), peak=11, duty=(1, 1))),
    dict(name="ECHO PLUCK", mono=0, fb=1, rep=(1, 5, 3),
         sid=dict(wave="pulse", ad=0x09, sr=0x09, pw=0x400, det=6),
         gb=dict(atk=0, dec=2, rel=1, duty=(2, 2), wave=WAVE_TRI, lvl=11, det=5),
         nes=dict(env=(0, 0.4, 0, 0.2), peak=11, duty=(2, 2))),
    dict(name="TREMOLO GATE", mono=0, fb=1,
         sid=dict(wave="pulse", ad=0x3A, sr=0xD9, pw=1600, det=8),
         gb=dict(atk=0, rel=2, duty=(2, 2), wave=WAVE_SQ, lvl=11, det=5),
         nes=dict(env=(0, 0, 1, 0.2), peak=10, duty=(2, 2), trem=(15, 8, 1))),
]

WAVES = {"tri": 0x10, "saw": 0x20, "pulse": 0x40}


def cc(param, mx):
    """Fat Chip GB scales a CC as value * (max + 1) >> 7: the smallest CC giving `param`."""
    return min(127, math.ceil(param * 128 / (mx + 1)))


def inc4(hz):            # 16-bit phase step per 4 ms
    return int(round(hz * 65536 / 250))


def nes_env(e, peak):
    """(attack step 8.8 per 10 ms, decay step, sustain level, release factor)"""
    if e == "pads":
        return 64, 26, 11, 5
    a, d, s, r = e
    sus = max(1, round(peak * s)) if s > 0 else 0
    atk = 0 if a < 0.015 else max(1, min(255, round(peak * 256 / (a * 100))))
    dec = 0 if d == 0 or sus >= peak else max(1, min(255, round((peak - sus) * 256 / (d * 100))))
    rel = 0 if r == 0 else max(1, min(68, round(10240 / (r * 1000))))
    return atk, dec, sus, rel


def build():
    cols = {}

    def put(name, v):
        cols.setdefault(name, []).append(v & 0xFF)

    for s in SOUNDS:
        S, G, N = s["sid"], s["gb"], s["nes"]
        put("sndMono", s["mono"])
        rp = s.get("rep")
        put("sndRp", 1 if rp else 0)
        put("sndRpTime", rp[0] if rp else 1)
        put("sndRpCount", (rp[1] if rp else 3) - 1)
        put("sndRpLevel", rp[2] if rp else 3)
        put("sndFat", s["fb"])
        # SID
        put("sndAD", S["ad"])
        put("sndSR", S["sr"])
        put("sndWave", WAVES[S["wave"]])
        pw = S.get("pw", 0x800)
        put("sndPwLo", pw)
        put("sndPwHi", pw >> 8)
        put("sndDet", S.get("det", 8))
        put("sndOct", S.get("oct", 0))
        put("sndGlide", S.get("glide", 0))
        f = S.get("filt")
        put("sndCut", f[0] if f else 0)
        put("sndRes", (f[1] << 4 | 7) if f else 0)
        put("sndFDep", f[2] if f else 0)
        r = inc4(f[3]) if f and f[2] else 0
        put("sndFRateL", r)
        put("sndFRateH", r >> 8)
        put("sndFEnv", f[4] if f else 0)
        p = S.get("pwm")
        put("sndPwm", p[0] if p else 0)
        r = inc4(p[1]) if p else 0
        put("sndPwmRL", r)
        put("sndPwmRH", r >> 8)
        v = S.get("vib")
        put("sndVib", min(127, round(v[0] * 0.0595 * 4096)) if v else 0)
        r = inc4(v[1]) if v else 0
        put("sndVibRL", r)
        put("sndVibRH", r >> 8)
        put("sndVibDel", min(255, round(v[2] * 250)) if v else 0)
        put("sndVibSpr", v[3] if v else 0)
        seq = S.get("duty") or N.get("seq")
        put("sndSeq", seq[0] if seq else 0)
        put("sndSeqMs", min(255, seq[1] // 4) if seq else 0)       # in 4 ms steps
        put("sndSeqSid", 1 if S.get("duty") else 0)
        # Game Boy (CCs)
        put("gbAtk", cc(G.get("atk", 0), 7))
        put("gbDec", cc(G.get("dec", 0), 7))
        put("gbRel", cc(G.get("rel", 0), 7))
        put("gbDuty1", cc(G["duty"][0], 3))
        put("gbDuty2", cc(G["duty"][1], 3))
        gl = G.get("glide", (0, 0, 0))
        put("gbGl1", cc(gl[0], 15))
        put("gbGl2", cc(gl[1], 15))
        put("gbGlW", cc(gl[2], 15))
        put("gbWMode", cc(G["wave"][0], 6))
        put("gbWShape", G["wave"][1] if G["wave"][0] == 1 else cc(G["wave"][1], 15))
        put("gbWarb", G.get("warble", 24))
        put("gbWSpd", G.get("wspeed", 40))
        lf = G.get("lfo")
        put("gbLDest", cc(lf[0], 2) if lf else 0)
        put("gbLShape", cc(lf[1], 4) if lf else 0)
        put("gbLRate", cc(lf[2], 31) if lf else 0)
        put("gbLDepth", cc(lf[3], 31) if lf else 0)
        put("gbLDelay", cc(lf[4], 15) if lf else 0)
        steps = round(G.get("det", 5) / 1.5625)
        put("gbDetA", max(0, (32 - steps) * 2))
        put("gbDetB", min(127, (32 + steps) * 2))
        put("gbLvl", cc(G.get("lvl", 15), 15))
        put("gbLvlW", cc(G.get("lvlw", 15), 15))
        put("gbOct", G.get("oct", 0))
        # MidiNES
        peak = N.get("peak", 15)
        if N["env"] is None:
            put("nesEnv", 0)
            atk = dec = sus = rel = 0
        else:
            put("nesEnv", 1)
            atk, dec, sus, rel = nes_env(N["env"], peak)
        put("nesAtk", atk)
        put("nesDec", dec)
        put("nesSus", sus if N["env"] is not None else 15)
        put("nesPeak", peak)
        put("nesRel", rel)
        put("nesDuty1", N["duty"][0] * 32)
        put("nesDuty2", N["duty"][1] * 32)
        t = N.get("trem")
        put("nesTrem", t[0] if t else 0)
        r = int(round(t[1] * 65536 / 100)) if t else 0      # per 10 ms
        put("nesTremRL", r)
        put("nesTremRH", r >> 8)
        put("nesTremSq", t[2] if t else 0)

    out = ["; Generated by tools/gen_sounds.py - do not edit. The sounds (V), in order:"]
    for i, s in enumerate(SOUNDS):
        out.append(f";  {i:2d} {s['name']}")
    out.append(f"NUM_SOUNDS equ {len(SOUNDS)}")
    for name, vals in cols.items():
        out.append(f"{name + ':':12s}.byte " + ",".join(f"${v:02X}" for v in vals))
    out.append("sndNameLo:  .byte " + ",".join(f"<sndN{i}" for i in range(len(SOUNDS))))
    out.append("sndNameHi:  .byte " + ",".join(f">sndN{i}" for i in range(len(SOUNDS))))
    for i, s in enumerate(SOUNDS):
        out.append(f'sndN{i}:{" " * (6 - len(str(i)))}.byte "{s["name"]:16s}",0')
    open(os.path.join(ROOT, "src", "soundtab.asm"), "w").write("\n".join(out) + "\n")
    return len(SOUNDS)


if __name__ == "__main__":
    print(build(), "sounds")
