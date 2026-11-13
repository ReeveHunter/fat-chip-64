#!/usr/bin/env python3
"""Chip Lab's demo patches (v0.30 / v0.31 effects) -> patch/demo-patches.json,
checked against the converter (gen_patches.py). Not built into Fat Chip 64:
Reeve sorts the ones he likes into banks in Chip Lab. tools/sync_chiplab.sh
copies the file to Chip Lab."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_patches as g  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")

SAW, PULSE, TRI, PT = 1, 2, 0, 5


def P(name, bank, character, fx, **kw):
    p = {"name": name}
    p.update(kw)
    p["character"] = character
    p["fx"] = fx
    return bank, p


def env(a, d, s, r):
    return {"attack": a, "decay": d, "sustain": s, "release": r}


DEMO = [
    # ---------------------------------------------------------------- leads
    P("BLIP LEAD", "LEADS", ["attack"], {
        "tone": {"sidWave": PULSE, "sidPw": 1024, "gbDuty1": 1, "gbDuty2": 1, "nesDuty1": 1, "nesDuty2": 1, "gbWaveMode": 1},
        "env": env(2, 300, 10, 240), "detune": {"cents": 6},
        "attack": {"blip": 1, "blipMs": 2},
        "vibrato": {"depth": 15, "vibRate": 5.5, "delay": 250}}, mono=1, fatBass=0),
    P("CHIP ARP STAB", "LEADS", ["attack"], {
        "tone": {"sidWave": PULSE, "sidPw": 2048, "gbWaveMode": 1},
        "env": env(2, 240, 6, 168), "detune": {"cents": 5},
        "attack": {"blip": 3, "blipMs": 1}}),
    P("SCOOP LEAD", "LEADS", ["penv"], {
        "tone": {"sidWave": SAW, "gbDuty1": 1, "gbWaveMode": 2},
        "env": env(8, 750, 12, 300), "detune": {"cents": 8},
        "penv": {"amount": -3, "time": 80},
        "vibrato": {"depth": 20, "vibRate": 5.8, "delay": 300}}, mono=1, fatBass=0),
    P("DIVE BOMB", "LEADS", ["penv"], {
        "tone": {"sidWave": PULSE, "sidPw": 1600, "gbWaveMode": 1},
        "env": env(2, 750, 13, 240), "detune": {"cents": 6},
        "penv": {"amount": 24, "time": 300}}, mono=1, fatBass=0),
    P("TAPE STOP LEAD", "LEADS", ["rdrop"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(8, 750, 12, 1500), "detune": {"cents": 7},
        "rdrop": {"amount": 12, "time": 800}}, mono=1, fatBass=0),
    P("CLIMB ECHO", "LEADS", ["repeat"], {
        "tone": {"sidWave": PULSE, "sidPw": 1024, "gbDuty1": 1, "gbWaveMode": 1},
        "env": env(2, 300, 8, 240), "detune": {"cents": 5},
        "repeat": {"time": 2, "repeats": 4, "level": 80, "shift": 12, "hop": 1}}, mono=1, fatBass=0),
    P("SCALE CASCADE", "LEADS", ["repeat"], {
        "tone": {"sidWave": TRI, "gbDuty1": 2, "gbWaveMode": 2},
        "env": env(2, 300, 6, 300), "detune": {"cents": 4},
        "repeat": {"time": 4, "repeats": 7, "level": 85, "shift": -1, "shiftIn": 1, "hop": 1}}, mono=1, fatBass=0),
    P("FIFTH ECHO", "LEADS", ["repeat"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 750, 10, 240), "detune": {"cents": 6},
        "repeat": {"time": 2, "repeats": 3, "level": 75, "shift": 7}}, mono=1, fatBass=0),
    P("CHIP PING PONG", "LEADS", ["repeat"], {
        "tone": {"sidWave": PULSE, "sidPw": 2048, "gbWaveMode": 1},
        "env": env(2, 240, 4, 168), "detune": {"cents": 5},
        "repeat": {"time": 1, "repeats": 5, "level": 85, "hop": 1}}),
    P("SLAPBACK", "LEADS", ["repeat"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 750, 12, 240), "detune": {"cents": 7},
        "repeat": {"time": 6, "repeats": 2, "level": 70, "hop": 2}}, mono=1, fatBass=0),
    # ---------------------------------------------------------------- pads and dynamics
    P("PUMP PAD", "PADS", ["tremolo"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(250, 750, 15, 1500), "detune": {"cents": 9},
        "tremolo": {"depth": 90, "tremSync": 3, "mode": 1},
        "warble": {"amount": 9, "on": ["gb"]}}),
    P("SLOW PUMP", "PADS", ["tremolo"], {
        "tone": {"sidWave": PT, "sidPw": 1024, "gbWaveMode": 2},
        "env": env(500, 750, 15, 2400), "detune": {"cents": 7},
        "tremolo": {"depth": 65, "tremSync": 2, "mode": 1}}),
    P("GATE PAD", "PADS", ["tremolo"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(80, 750, 15, 750), "detune": {"cents": 8},
        "tremolo": {"depth": 100, "tremSync": 7, "mode": 2}}),
    P("TRANCE GATE", "PADS", ["tremolo", "pwm"], {
        "tone": {"sidWave": PULSE, "sidPw": 1600, "gbWaveMode": 1},
        "env": env(24, 750, 15, 300), "detune": {"cents": 10},
        "tremolo": {"depth": 100, "tremSync": 7, "mode": 3},
        "pwm": {"depth": 40, "pwmRate": 0.4}}),
    P("DOTTED GATE", "PADS", ["tremolo"], {
        "tone": {"sidWave": PT, "sidPw": 2048, "gbWaveMode": 2},
        "env": env(16, 750, 15, 240), "detune": {"cents": 6},
        "tremolo": {"depth": 100, "tremSync": 7, "mode": 4}}),
    P("SYNC WOBBLE", "PADS", ["tremolo"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(100, 750, 15, 750), "detune": {"cents": 7},
        "tremolo": {"depth": 60, "tremSync": 6, "shape": 1}}),
    P("SIGH PAD", "PADS", ["rdrop", "filter"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(500, 750, 15, 2400), "detune": {"cents": 8},
        "rdrop": {"amount": 2, "time": 1500},
        "filter": {"cutoff": 90, "resonance": 6, "lfoDepth": 40, "filtLfoRate": 0.2}}),
    # ---------------------------------------------------------------- bass
    P("PLUCK BASS DROP", "BASS", ["rdrop", "filter"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 240, 4, 168), "detune": {"cents": 5},
        "rdrop": {"amount": 5, "time": 200},
        "filter": {"cutoff": 60, "resonance": 9, "envAmount": 80}}, mono=1, octSid=-1),
    P("SCOOP BASS", "BASS", ["penv", "glide"], {
        "tone": {"sidWave": PULSE, "sidPw": 1024, "gbDuty1": 1, "gbWaveMode": 2},
        "env": env(2, 750, 12, 168), "detune": {"cents": 4},
        "penv": {"amount": -5, "time": 40},
        "glide": {"time": 1}}, mono=1, octSid=-1),
    P("BLIP BASS", "BASS", ["attack"], {
        "tone": {"sidWave": PULSE, "sidPw": 1600, "gbWaveMode": 2},
        "env": env(2, 300, 10, 168), "detune": {"cents": 4},
        "attack": {"blip": 1, "blipMs": 1}}, mono=1, octSid=-1),
    P("808 DROP", "BASS", ["penv"], {
        "tone": {"sidWave": TRI, "gbWaveMode": 2},
        "env": env(2, 1500, 0, 750), "detune": {"cents": 3},
        "penv": {"amount": 12, "time": 150}}, mono=1, octSid=-1),
    P("FALL BASS", "BASS", ["rdrop"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 750, 12, 300), "detune": {"cents": 5},
        "rdrop": {"amount": 12, "time": 300}}, mono=1, octSid=-1),
    # ---------------------------------------------------------------- fx
    P("LASER", "FX", ["penv"], {
        "tone": {"sidWave": PULSE, "sidPw": 512, "gbDuty1": 0, "gbDuty2": 0, "nesDuty1": 0, "nesDuty2": 0, "gbWaveMode": 1},
        "env": env(2, 240, 0, 168), "detune": {"cents": 4},
        "penv": {"amount": 24, "time": 40}}),
    P("ZAP CLICK", "FX", ["penv", "attack"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 168, 0, 114), "detune": {"cents": 6},
        "attack": {"blip": 0, "click": 1},
        "penv": {"amount": 24, "time": 20}}),
    P("COIN BLIP", "FX", ["attack"], {
        "tone": {"sidWave": PULSE, "sidPw": 2048, "gbWaveMode": 1},
        "env": env(2, 300, 0, 240), "detune": {"cents": 3},
        "attack": {"blip": 2, "blipMs": 4}}),
    P("POWER DOWN", "FX", ["rdrop"], {
        "tone": {"sidWave": PULSE, "sidPw": 1024, "gbWaveMode": 1},
        "env": env(2, 750, 15, 3000), "detune": {"cents": 6},
        "rdrop": {"amount": 24, "time": 2000}}),
    P("RAIN DROPS", "FX", ["repeat"], {
        "tone": {"sidWave": TRI, "gbDuty1": 0, "gbWaveMode": 2},
        "env": env(2, 168, 0, 168), "detune": {"cents": 4},
        "repeat": {"time": 5, "repeats": 8, "level": 70, "shift": 2, "shiftIn": 1, "hop": 1}}),
    P("UFO", "FX", ["vibrato", "tremolo"], {
        "tone": {"sidWave": TRI, "gbWaveMode": 2},
        "env": env(80, 750, 15, 750), "detune": {"cents": 10},
        "vibrato": {"depth": 50, "vibRate": 9},
        "tremolo": {"depth": 50, "tremRate": 3.5}}),
    # ---------------------------------------------------------------- fat
    P("FAT CLICK", "FAT", ["detune", "attack"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(2, 750, 12, 750), "detune": {"cents": 9},
        "attack": {"blip": 0, "click": 1},
        "warble": {"amount": 9, "on": ["gb"]}}),
    P("FAT SCOOP", "FAT", ["detune", "penv"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(8, 750, 12, 750), "detune": {"cents": 7},
        "penv": {"amount": -2, "time": 40},
        "warble": {"amount": 9, "on": ["gb"]}}),
    P("FAT TAPE", "FAT", ["detune", "rdrop", "warble"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(8, 750, 12, 750), "detune": {"cents": 7},
        "rdrop": {"amount": 3, "time": 400},
        "warble": {"amount": 15}}),
    P("BIG SCOOP", "FAT", ["detune", "penv"], {
        "tone": {"sidWave": SAW, "gbWaveMode": 2},
        "env": env(8, 750, 13, 750), "detune": {"cents": 20},
        "penv": {"amount": -7, "time": 200}}),
]

if __name__ == "__main__":
    names = [p["name"] for _, p in DEMO]
    assert len(set(names)) == len(names)
    built = {p["name"] for p in g.PATCHES}
    for bank, p in DEMO:
        assert len(p["name"]) <= 16 and p["name"] == p["name"].upper(), p["name"]
        assert p["name"] not in built, p["name"]
        b = g.patch_bytes(p)                      # (asserts unknown settings and converts)
        assert len(b) == json.load(open(os.path.join(ROOT, "patch", "c64-layout.json")))["patchSize"]
    out = {"format": "fat-chip-patches", "version": 1,
           "doc": "Chip Lab's demo patches (Fat Chip 64 v0.30 / v0.31 effects: ATTACK, BEND IN / OUT, climbing and chip-hopping echoes, tempo PUMP and GATE). Not built into Fat Chip 64: sort the ones you like into banks. 'suggest' is a starting guess at each one's bank.",
           "suggest": {p["name"]: bank for bank, p in DEMO},
           "patches": [p for _, p in DEMO]}
    with open(os.path.join(ROOT, "patch", "demo-patches.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(len(DEMO), "demo patches")
