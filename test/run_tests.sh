#!/bin/sh
cd "$(dirname "$0")/.."
fail=0
for t in test/test_main.py test/test_arp.py test/test_modes.py test/test_nesenv.py test/test_v010.py test/test_fast_link.py test/test_midiin.py test/test_v012.py test/test_v013.py test/test_v014.py test/test_with_gb.py test/test_gb_channels.py; do
  echo "== $t"
  python3 -I "$t" | tail -1 || fail=1
done
exit $fail
