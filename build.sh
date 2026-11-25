#!/bin/sh
# Build Fat Chip 64. Needs dasm (https://github.com/dasm-assembler/dasm) on PATH or in $DASM.
set -e
cd "$(dirname "$0")"
DASM=${DASM:-dasm}
mkdir -p bin
python3 tools/gen_tables.py >/dev/null
python3 tools/check_effects.py >/dev/null
python3 tools/gen_patches.py >/dev/null
python3 tools/gen_beat_book.py >/dev/null
python3 tools/gen_menu.py >/dev/null
python3 tools/gen_beats.py >/dev/null
python3 tools/gen_bend.py >/dev/null
cd src
rm -f ../bin/fatchip64-image.prg
$DASM main.asm -f1 -o../bin/fatchip64-image.prg -s../bin/fatchip64.sym -l../bin/fatchip64.lst -v1 > ../bin/dasm.log 2>&1 || true
grep "error:\|Fatal" ../bin/dasm.log && { rm -f ../bin/fatchip64-image.prg; echo "dasm failed (bin/dasm.log)"; exit 1; }
[ -s ../bin/fatchip64-image.prg ] || { echo "dasm failed"; exit 1; }
cd ..
DASM=$DASM python3 tools/crunch.py          # (v0.41: packed; it unpacks itself at start)
# v0.65: the tests' build, bin/test/: the same program with a fixed set of patches
# (patch/patches-test.json), so the tests don't change whenever the built-in ones do
mkdir -p bin/test
FATCHIP_PATCHES=patch/patches-test.json python3 tools/gen_patches.py >/dev/null
FATCHIP_PATCHES=patch/patches-test.json python3 tools/gen_menu.py >/dev/null
cd src
rm -f ../bin/test/fatchip64-image.prg
$DASM main.asm -f1 -o../bin/test/fatchip64-image.prg -s../bin/test/fatchip64.sym -v1 > ../bin/test/dasm.log 2>&1 || true
grep "error:\|Fatal" ../bin/test/dasm.log && { echo "dasm failed on the tests' build (bin/test/dasm.log)"; exit 1; }
cd ..
python3 tools/gen_patches.py >/dev/null      # (src/ back to the real patches)
python3 tools/gen_menu.py >/dev/null
rm -f bin/test/dasm.log
ls -la bin/fatchip64.prg
