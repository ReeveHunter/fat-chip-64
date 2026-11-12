#!/bin/sh
# Copy the patch definition, the built-in patches, the C64 layout and the
# JavaScript converter to Chip Lab (the ReeveHunter.github.io repo next to this
# one). Run after changing anything in patch/ or tools/gen_patches.py.
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_patches.py >/dev/null
DEST=${1:-../ReeveHunter.github.io/fatchip/chiplab}
cp patch/effects.json patch/patches.json patch/c64-layout.json patch/fatchip-patch.js "$DEST"/
echo "copied to $DEST"
