#!/usr/bin/env python3
"""Check patch/effects.json, the shared definition of a Fat Chip patch.

Run it after any change to the file. It looks for the mistakes that would
otherwise only show up on the C64 or in Chip Lab:
  - ids missing or used twice (in a list, and effect ids overall)
  - a type it doesn't know, or a blend that isn't lerp / log / switch
  - int / ms / hz ranges back to front, defaults or dice ranges outside them
  - enums and flags without values, defaults that aren't one of them
  - a 'map' naming a chip other than sid / gb / nes
  - an effect's 'chips' or 'voices' that make no sense
  - the patch's CHARACTER default naming effects that don't exist
Exit status 1 if anything is wrong.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "..", "patch", "effects.json")

TYPES = {"int", "ms", "hz", "enum", "flags", "bool", "text", "effects", "patch"}
BLENDS = {"lerp", "log", "switch"}
CHIPS = {"sid", "gb", "nes"}

problems = []


def bad(where, msg):
    problems.append(f"{where}: {msg}")


def check_param(where, p):
    for k in ("id", "name", "type", "default", "blend"):
        if k not in p:
            bad(where, f"no '{k}'")
            return
    t = p["type"]
    if t not in TYPES:
        bad(where, f"type '{t}' unknown")
    if p["blend"] not in BLENDS:
        bad(where, f"blend '{p['blend']}' unknown")
    if p["blend"] == "log" and t not in ("int", "ms", "hz"):
        bad(where, "log blend on a non-number")
    d = p["default"]
    if t in ("int", "hz") or (t == "ms" and "values" not in p):
        lo, hi = p.get("min"), p.get("max")
        if lo is None or hi is None:
            bad(where, "needs min and max")
        else:
            if lo > hi:
                bad(where, f"min {lo} > max {hi}")
            if not lo <= d <= hi:
                bad(where, f"default {d} outside {lo}..{hi}")
            r = p.get("rand")
            if r is not None and not (lo <= r[0] <= r[1] <= hi):
                bad(where, f"rand {r} outside {lo}..{hi} (or back to front)")
            if p["blend"] == "log" and lo <= 0 and t == "hz":
                bad(where, "log blend needs a range above 0")
    if t == "ms" and "values" in p:
        v = p["values"]
        if v != sorted(v):
            bad(where, "ms values not in order")
        if d not in v:
            bad(where, f"default {d} isn't one of the values")
        r = p.get("rand")
        if r is not None and not (v[0] <= r[0] <= r[1] <= v[-1]):
            bad(where, f"rand {r} outside {v[0]}..{v[-1]}")
    if t == "enum":
        v = p.get("values")
        if not v:
            bad(where, "enum without values")
        elif not 0 <= d < len(v):
            bad(where, f"default {d} isn't an index into {len(v)} values")
        else:
            r = p.get("rand")
            if r is not None and not (0 <= r[0] <= r[1] < len(v)):
                bad(where, f"rand {r} outside 0..{len(v) - 1}")
            if len(set(v)) != len(v):
                bad(where, "the same value twice")
    if t == "flags":
        v = p.get("values")
        if not v:
            bad(where, "flags without values")
        elif not 0 <= d < (1 << len(v)):
            bad(where, f"default {d} has bits beyond {len(v)} flags")
    if t == "bool" and d not in (0, 1):
        bad(where, "bool default must be 0 or 1")
    if t == "text" and len(d) > p.get("maxLen", 16):
        bad(where, "default text too long")
    for chip in p.get("map", {}):
        if chip not in CHIPS:
            bad(where, f"map names chip '{chip}'")
    if len(p["name"]) > 20:
        bad(where, f"name '{p['name']}' longer than 20 (the menu's label column)")


def check_list(where, params):
    seen = set()
    for i, p in enumerate(params):
        w = f"{where}[{i}] {p.get('id', '?')}"
        if p.get("id") in seen:
            bad(w, "id used twice")
        seen.add(p.get("id"))
        check_param(w, p)


def main():
    with open(PATH) as f:
        d = json.load(f)
    if d.get("format") != "fat-chip-effects":
        bad("file", "format isn't fat-chip-effects")
    check_list("patch", d["patch"])
    check_list("session", d.get("session", []))
    check_list("play", d.get("play", []))
    ids = set()
    for e in d["effects"]:
        w = f"effect {e.get('id', '?')}"
        if e.get("id") in ids:
            bad(w, "id used twice")
        ids.add(e.get("id"))
        for chip in e.get("chips", []):
            if chip not in CHIPS:
                bad(w, f"chips names '{chip}'")
        v = e.get("voices", 0)
        if not (v == "rest" or (isinstance(v, int) and 0 <= v <= 9)):
            bad(w, f"voices {v!r}")
        ro = e.get("randOn")
        if e.get("alwaysOn"):
            if ro is not None:
                bad(w, "always on, so no randOn")
        elif ro is None or not 0 <= ro <= 1:
            bad(w, "randOn (the dice's chance to turn it on) 0-1 missing")
        if len(e.get("name", "")) > 20:
            bad(w, "name longer than 20")
        check_list(w, e["params"])
    char = next(p for p in d["patch"] if p["id"] == "character")
    for eid in char["default"]:
        if eid not in ids:
            bad("patch character", f"names effect '{eid}'")
    n = sum(len(e["params"]) for e in d["effects"])
    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} problem(s)")
        sys.exit(1)
    print(f"ok: {len(d['effects'])} effects, {n} effect parameters, {len(d['patch'])} patch settings, "
          f"{len(d.get('session', []))} session and {len(d.get('play', []))} play settings")


if __name__ == "__main__":
    main()
