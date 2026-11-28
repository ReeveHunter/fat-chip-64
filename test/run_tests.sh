#!/bin/sh
cd "$(dirname "$0")/.."
fail=0
for t in test/test_main.py test/test_arp.py test/test_modes.py test/test_nesenv.py test/test_v010.py test/test_fast_link.py test/test_midiin.py test/test_v012.py test/test_v013.py test/test_v014.py test/test_v015.py test/test_v016.py test/test_v017.py test/test_v018.py test/test_v019.py test/test_v020.py test/test_v021.py test/test_v022.py test/test_v023.py test/test_v024.py test/test_v027.py test/test_v028.py test/test_v030.py test/test_v031.py test/test_v032.py test/test_v033.py test/test_v034.py test/test_v035.py test/test_v037.py test/test_v039.py test/test_v040.py test/test_crunch.py test/test_v042.py test/test_v043.py test/test_v044.py test/test_v045.py test/test_v046.py test/test_v047.py test/test_v048.py test/test_v049.py test/test_v050.py test/test_v051.py test/test_v052.py test/test_v053.py test/test_v054.py test/test_v055.py test/test_v056.py test/test_v057.py test/test_v058.py test/test_v059.py test/test_v060.py test/test_v061.py test/test_v065.py test/test_v066.py test/test_v068.py test/test_patch_js.py test/test_with_gb.py test/test_gb_channels.py; do
  echo "== $t"
  python3 -I "$t" | tail -1 || fail=1
done
exit $fail
