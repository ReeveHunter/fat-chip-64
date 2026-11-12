#!/usr/bin/env python3
"""patch/fatchip-patch.js (Chip Lab) and tools/gen_patches.py give the same
bytes and SysEx: every built-in patch, and 300 dice-rolled ones. Needs node."""
import json
import os
import random
import shutil
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_patches  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


if not shutil.which("node"):
    print("SKIP: no node")
    print("\n0 failure(s)")
    sys.exit(0)

D = gen_patches.DEF
rnd = random.Random(7)


def roll(q):
    t = q["type"]
    if t in ("int", "hz") or (t == "ms" and "values" not in q):
        lo, hi = q.get("rand", [q["min"], q["max"]])
        return rnd.randint(lo, hi) if t != "hz" else round(rnd.uniform(lo, hi), 2)
    if t == "ms":
        return rnd.choice(q["values"])
    if t == "enum":
        lo, hi = q.get("rand", [0, len(q["values"]) - 1])
        return rnd.randint(lo, hi)
    if t == "flags":
        return rnd.randint(1, (1 << len(q["values"])) - 1)
    if t == "bool":
        return rnd.randint(0, 1)
    return q["default"]


def dice():
    p = {"name": "DICE %d" % rnd.randint(0, 999)}
    for q in D["patch"]:
        if q["type"] in ("int", "enum", "bool"):
            p[q["id"]] = roll(q)
    p["fx"] = {}
    for e in D["effects"]:
        if e.get("alwaysOn") or rnd.random() < e.get("randOn", 0.5):
            vals = {q["id"]: roll(q) for q in e["params"]}
            if rnd.random() < 0.3:
                vals["on"] = rnd.sample(e.get("chips", ["sid", "gb", "nes"]), rnd.randint(1, len(e.get("chips", ["sid", "gb", "nes"]))))
            p["fx"][e["id"]] = vals
    return p


patches = list(gen_patches.PATCHES) + [dice() for _ in range(300)]
js = """
const fs = require("fs"), FC = require(process.argv[1] + "/patch/fatchip-patch.js");
const fc = FC.make(JSON.parse(fs.readFileSync(process.argv[1] + "/patch/effects.json")), JSON.parse(fs.readFileSync(process.argv[1] + "/patch/c64-layout.json")));
const P = JSON.parse(fs.readFileSync(0));
process.stdout.write(JSON.stringify(P.map(p => fc.sysex(p))));
"""
out = subprocess.run(["node", "-e", js, os.path.abspath(ROOT)], input=json.dumps(patches), capture_output=True, text=True)
check("node ran", out.returncode == 0, out.stderr[-300:])
got = json.loads(out.stdout) if out.returncode == 0 else []
want = [gen_patches.sysex(p) for p in patches]
n = len(gen_patches.PATCHES)
check(f"the {n} built-in patches: the same SysEx", got[:n] == want[:n])
bad = [i for i in range(n, len(patches)) if got[i:i + 1] != want[i:i + 1]]
if bad:
    a, b = gen_patches.patch_bytes(patches[bad[0]]), got[bad[0]]
    names = json.load(open(os.path.join(ROOT, "patch", "c64-layout.json")))["fields"]
    info = [(names[k // 1], a[k]) for k in range(len(names))]
check("300 dice-rolled patches: the same SysEx", not bad, (len(bad), patches[bad[0]] if bad else ""))
if bad:
    jb = got[bad[0]][6:-1]
    jb = [jb[i] << 4 | jb[i + 1] for i in range(0, len(jb), 2)]
    print("  first difference:", [(names[k], a[k], jb[k]) for k in range(len(names)) if a[k] != jb[k]])
print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
