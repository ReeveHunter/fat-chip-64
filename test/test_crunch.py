#!/usr/bin/env python3
"""Fat Chip 64 v0.41: the packed program file. Run as a C64 would (loaded
at $0801, RUN), it unpacks to exactly the assembled image (the code from
$0801, the tables at $E000) and starts; then it plays."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sim import C64, ROOT  # noqa: E402

fails = 0


def check(name, cond, info=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f"  [{info}]" if info != "" else ""))
    fails += 0 if cond else 1


packed = os.path.join(ROOT, "bin", "fatchip64.prg")
size = os.path.getsize(packed)
check("the program file ends below the I/O at $D000", 0x0801 + size - 2 <= 0xD000, hex(0x0801 + size - 2))

c = C64(prg=packed, channels=None, boot=False)
line = bytes(c.raw[0x0805:0x0810])
check("10 SYS (the unpacker, at the end of the file)", line[0] == 0x9E, line)
c.cpu.pc = int(line[1:line.index(0)])
data = open(os.path.join(ROOT, "bin", "fatchip64-image.prg"), "rb").read()
img = bytearray(65536)                           # (the image as assembled)
img[0x0801:0x0801 + len(data) - 2] = data[2:]
hp, hs, he = c.sym["hiPhys"], c.sym["hiStart"], c.sym["hiEnd"]
img[hs:he] = img[hp:hp + he - hs]
start = c.sym["Start"]
while c.cpu.pc != start and c.cpu.processorCycles < 4_000_000:
    c.cpu.step()
secs = c.cpu.processorCycles / 1_000_000
check("it unpacks and jumps to Start (within a second and a half)", c.cpu.pc == start and secs < 1.5, f"{secs:.2f} s")
code_ok = c.raw[0x0810:c.sym["hiPhys"]] == img[0x0810:c.sym["hiPhys"]]
hi_ok = c.raw[c.sym["hiStart"]:c.sym["hiEnd"]] == img[c.sym["hiStart"]:c.sym["hiEnd"]]
check("the code from $0810 matches the image", code_ok)
check("the tables at $E000 match", hi_ok)
c.run_until(c.sym["Loop"], limit=3_000_000)
c.run_ms(500)
check("then it runs: the play screen", "FAT CHIP 64" in c.screen_row(0), c.screen_row(0))
c.midi_in(0x90, 60, 100, ms=100)
check("... and plays (SID voice 1 gated)", c.raw[0xD404] & 1 == 1, hex(c.raw[0xD404]))

print(f"\n{fails} failure(s)")
sys.exit(1 if fails else 0)
