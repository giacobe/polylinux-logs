#!/bin/sh
set -eu
root=${1:-/}
failed=0
for level in 1 2 3 4 5 6 7 8 9 10; do
    home="$root/home/level$level"
    if [ ! -f "$home/README.txt" ]; then
        echo "level$level: README.txt missing" >&2
        failed=1
    fi
done
for forbidden in \
    "$root/answers" \
    "$root/root/answers" \
    "$root/var/lib/system-logs/answers"; do
    if [ -e "$forbidden" ]; then
        echo "forbidden client-side answer store: $forbidden" >&2
        failed=1
    fi
done
[ "$failed" -eq 0 ]
echo 'Packaged level structure contains no lab answer store.'