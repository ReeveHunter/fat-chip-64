#!/bin/sh
# Build Fat Chip 64. Needs dasm (https://github.com/dasm-assembler/dasm) on PATH or in $DASM.
set -e
cd "$(dirname "$0")"
DASM=${DASM:-dasm}
mkdir -p bin
python3 tools/gen_tables.py >/dev/null
cd src
$DASM main.asm -f1 -o../bin/fatchip64.prg -s../bin/fatchip64.sym -l../bin/fatchip64.lst -v1 | grep -v "^Complete" || true
cd ..
ls -la bin/fatchip64.prg
