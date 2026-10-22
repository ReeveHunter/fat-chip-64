#!/bin/sh
cd "$(dirname "$0")/.."
fail=0
for t in test/test_main.py test/test_with_gb.py; do
  echo "== $t"
  python3 -I "$t" | tail -1 || fail=1
done
exit $fail
