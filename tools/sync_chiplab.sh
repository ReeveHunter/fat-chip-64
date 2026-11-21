#!/bin/sh
# Copy the patch definition, the built-in patches, the C64 layout and the
# JavaScript converter to Chip Lab (the ReeveHunter.github.io repo next to this
# one), and the beats to the beats page. Run after changing anything in patch/,
# tools/gen_patches.py, tools/gen_beat_book.py or the clip data (patch/clips.json,
# patch/clip-names.json: tools/analyze_clips.py).
set -e
cd "$(dirname "$0")/.."
python3 tools/gen_patches.py >/dev/null
python3 tools/make_demo_patches.py >/dev/null
DEST=${1:-../ReeveHunter.github.io/fatchip/chiplab}
cp patch/effects.json patch/patches.json patch/demo-patches.json patch/c64-layout.json patch/fatchip-patch.js "$DEST"/
echo "copied to $DEST"
# the beats page plays patch/beats.json (tools/gen_beat_book.py)
python3 tools/gen_beat_book.py >/dev/null
BEATS=$(dirname "$DEST")/beats
cp patch/beats.json "$BEATS"/
echo "copied beats.json to $BEATS"
# the Beat Lab: clips, names, neighbours, layers and the starting-point beats
python3 tools/gen_beatlab_data.py >/dev/null
LAB=$(dirname "$DEST")/beatlab
cp patch/beatlab.json "$LAB"/
echo "copied beatlab.json to $LAB"
