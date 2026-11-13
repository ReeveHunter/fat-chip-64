#!/bin/sh
cd "$(dirname "$0")/.."
fail=0
for t in test/test_main.py test/test_arp.py test/test_modes.py test/test_nesenv.py test/test_v010.py test/test_fast_link.py test/test_midiin.py test/test_v012.py test/test_v013.py test/test_v014.py test/test_v015.py test/test_v016.py test/test_v017.py test/test_v018.py test/test_v019.py test/test_v020.py test/test_v021.py test/test_v022.py test/test_v023.py test/test_v024.py test/test_v027.py test/test_patch_js.py test/test_with_gb.py test/test_gb_channels.py; do
  echo "== $t"
  python3 -I "$t" | tail -1 || fail=1
done
exit $fail
