#!/bin/sh
# Build Fat Chip 64. Needs dasm (https://github.com/dasm-assembler/dasm) on PATH or in $DASM.
set -e
cd "$(dirname "$0")"
DASM=${DASM:-dasm}
mkdir -p bin
python3 tools/gen_tables.py >/dev/null
python3 tools/check_effects.py >/dev/null
python3 tools/gen_patches.py >/dev/null
python3 tools/gen_menu.py >/dev/null
python3 tools/gen_beats.py >/dev/null
python3 tools/gen_bend.py >/dev/null
cd src
rm -f ../bin/fatchip64-image.prg
$DASM main.asm -f1 -o../bin/fatchip64-image.prg -s../bin/fatchip64.sym -l../bin/fatchip64.lst -v1 | grep -v "^Complete" || true
[ -s ../bin/fatchip64-image.prg ] || { echo "dasm failed"; exit 1; }
cd ..
DASM=$DASM python3 tools/crunch.py          # (v0.41: packed; it unpacks itself at start)
ls -la bin/fatchip64.prg
