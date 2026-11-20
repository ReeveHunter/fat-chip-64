#!/usr/bin/env python3
"""Fat Chip 64 v0.41: pack the assembled image into the program file.

bin/fatchip64-image.prg is what dasm makes: the code from $0801, then the
tables for $E000 (at hiPhys). A C64 program file has to end below the I/O at
$D000, so: the tables are packed (a plain LZ: literal runs and copies from
back in the output), and as much of the code's tail as it takes to fit; the
rest of the code stays as it is, in place. The file: that code, the packed
tail, the packed tables, then src/crunch/depack.asm, which the BASIC line now
SYSes: it unpacks them and starts the program. Checks the tail unpacks without
overwriting packed bytes it hasn't read yet. (Little to unpack: quick.)"""
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FILE_TOP = int(os.environ.get("CRUNCH_TOP", "0xD000"), 16)   # (the program file ends below the I/O; lower: a test)


def syms(path):
    out = {}
    for line in open(path):
        p = line.split()
        if len(p) >= 2:
            try:
                out[p[0]] = int(p[1], 16)
            except ValueError:
                pass
    return out


def pack(data):
    """-> (stream, tokens): LZ with hash chains on 3-byte keys, lazy by one.
    Near copies (d <= 256): 2 bytes for 2-65; far: 3 bytes for 3-66."""
    n = len(data)
    heads = {}

    def add(pos):
        if pos + 3 <= n:
            heads.setdefault(bytes(data[pos:pos + 3]), []).append(pos)

    def best(i):
        bl, bd = 0, 0
        if i + 2 <= n:
            # near 2-byte matches (not in the 3-byte hash)
            for d in range(1, min(256, i) + 1):
                j = i - d
                ln = 0
                while ln < 65 and i + ln < n and data[j + ln] == data[i + ln]:
                    ln += 1
                if ln > bl:
                    bl, bd = ln, d
                    if ln == 65:
                        break
        if i + 3 <= n:
            for j in reversed(heads.get(bytes(data[i:i + 3]), [])[-48:]):
                d = i - j
                if d > 0xFFFF:
                    break
                if d <= 256:
                    continue
                ln = 0
                while ln < 66 and i + ln < n and data[j + ln] == data[i + ln]:
                    ln += 1
                if ln > bl and ln >= 4:
                    bl, bd = ln, d
        return bl, bd

    def worth(ln, d):
        return ln >= (2 if d <= 256 else 4) and (d <= 256 or ln >= 4)

    def gain(ln, d):
        return ln - (2 if d <= 256 else 3) if worth(ln, d) else 0

    out = bytearray()
    toks = []
    lits = bytearray()

    def flush():
        nonlocal lits
        while lits:
            run = lits[:128]
            out.append(len(run) - 1)
            out.extend(run)
            toks.append((1 + len(run), len(run)))
            lits = lits[128:]

    i = 0
    cur = best(0)
    while i < n:
        ln, d = cur
        if d <= 256 and ln > 65:
            ln = 65
        if worth(ln, d):
            nxt = best(i + 1) if i + 1 < n else (0, 0)
            if gain(*nxt) > gain(ln, d) + 1:            # lazy: a literal, then the better one
                lits.append(data[i])
                add(i)
                i += 1
                cur = nxt
                continue
            flush()
            if d <= 256:
                out.append(0x80 | (ln - 2))
                out.append(d - 1)
                toks.append((2, ln))
            else:
                out.append(0xC0 | (ln - 3))
                out.append(d & 255)
                out.append(d >> 8)
                toks.append((3, ln))
            for k in range(ln):
                add(i + k)
            i += ln
        else:
            lits.append(data[i])
            add(i)
            i += 1
        cur = best(i) if i < n else (0, 0)
    flush()
    out += bytes([0xC0, 0, 0])
    return bytes(out), toks


def unpack(stream):
    out = bytearray()
    i = 0
    while True:
        t = stream[i]
        i += 1
        if t < 0x80:
            out += stream[i:i + t + 1]
            i += t + 1
        elif t < 0xC0:
            ln, d = (t & 0x3F) + 2, stream[i] + 1
            i += 1
            for _ in range(ln):
                out.append(out[-d])
        else:
            ln, d = (t & 0x3F) + 3, stream[i] | stream[i + 1] << 8
            i += 2
            if d == 0:
                return bytes(out)
            for _ in range(ln):
                out.append(out[-d])


def excess(toks):
    """the most the output gets ahead of the input, unpacking forward"""
    m = r = w = 0
    for nin, nout in toks:
        r += nin
        w += nout
        m = max(m, w - r)
    return m


def main():
    s = syms(os.path.join(ROOT, "bin", "fatchip64.sym"))
    img = open(os.path.join(ROOT, "bin", "fatchip64-image.prg"), "rb").read()
    load = img[0] | img[1] << 8
    mem = bytearray(65536)
    mem[load:load + len(img) - 2] = img[2:]
    code_end = s["hiPhys"]
    hi = bytes(mem[code_end:code_end + s["hiEnd"] - s["hiStart"]])
    io = bytes(mem[s["ioPhys"]:s["ioPhys"] + s["ioEnd"] - s["ioStart"]])
    hs, _ = pack(hi)
    ios, _ = pack(io)
    assert unpack(hs) == hi and unpack(ios) == io
    hs_len = len(hs) + len(ios)                       # (v0.60: the $D000 data follows the $E000 tables)
    cdir = os.path.join(ROOT, "src", "crunch")
    dasm = os.environ.get("DASM", "dasm")
    dep_len = 220                                     # (depack.bin is 210; checked below. v0.58: was 160, too few; v0.60: 200)

    def layout(tail):
        """the packed tables and data first (they unpack first, to $E000 and
        $D000), then the packed tail, far enough up that unpacking it never
        writes over bytes it hasn't read yet (v0.60: the tables always sit in
        the room the tail needs, so every page packed gains)"""
        ts, toks = pack(bytes(mem[tail:code_end])) if tail < code_end else (bytes([0xC0, 0, 0]), [])
        tail_src = tail + max(excess(toks), hs_len)
        return ts, toks, tail_src, tail, tail_src + len(ts)

    # the least packing that fits (the tail's start in pages, down from the end)
    tail = code_end
    while True:
        ts, toks, tail_src, hi_src, dep = layout(tail)
        dep = max(dep, code_end)                      # (v0.58: the unpacker above the code, even when the packed data ends lower)
        if dep + dep_len <= FILE_TOP:
            break
        tail = (tail - 1) & 0xFF00 if tail & 0xFF else tail - 0x400
        assert tail > 0x0900, "can't fit"
    assert tail == code_end or unpack(ts) == bytes(mem[tail:code_end])
    open(os.path.join(cdir, "params.asm"), "w").write(
        f"DEP_ORG     equ ${dep:04X}\nTAIL_SRC    equ ${tail_src:04X}\nTAIL_DEST   equ ${tail:04X}\n"
        f"HI_SRC      equ ${hi_src:04X}\nHI_DEST     equ ${s['hiStart']:04X}\nSTART       equ ${s['Start']:04X}\n"
        f"IO_SRC      equ ${hi_src + len(hs):04X}\nIO_DEST     equ ${s['ioStart']:04X}\n")
    subprocess.run([dasm, "depack.asm", "-f3", "-odepack.bin"], cwd=cdir, check=True, stdout=subprocess.DEVNULL)
    dp = open(os.path.join(cdir, "depack.bin"), "rb").read()
    assert dep + len(dp) <= FILE_TOP, "the unpacker runs into the I/O"
    out = bytearray(mem[0x0801:tail])
    out += bytes(dep - tail)
    for at, b in ((tail_src, ts), (hi_src, hs), (hi_src + len(hs), ios)):
        out[at - 0x0801:at - 0x0801 + len(b)] = b
    out += dp
    sys_line = bytes([0x0D, 0x08, 0x0A, 0x00, 0x9E]) + str(dep).encode() + bytes(3)
    assert len(str(dep)) == 5 and 0x0801 + len(sys_line) <= 0x0810
    out[0:len(sys_line)] = sys_line                   # 10 SYS (the unpacker)
    open(os.path.join(ROOT, "bin", "fatchip64.prg"), "wb").write(bytes([0x01, 0x08]) + out)
    print(f"code ${0x0801:04X}-${tail:04X} as is, ${tail:04X}-${code_end:04X} packed "
          f"{code_end - tail} -> {len(ts)}; $E000 tables {len(hi)} -> {len(hs)}; $D000 data {len(io)} -> {len(ios)}; "
          f"program file ends ${0x0801 + len(out):04X}, SYS {dep}")


if __name__ == "__main__":
    sys.exit(main())
