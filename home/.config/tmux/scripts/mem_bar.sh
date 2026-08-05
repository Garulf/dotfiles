#!/bin/sh
# Memory in use as a single vertical bar. MemAvailable already accounts for
# reclaimable cache, so this tracks pressure rather than raw allocation.
set -eu

LEVELS=8

total=0
available=0
while read -r field value _; do
    case "$field" in
        MemTotal:) total=$value ;;
        MemAvailable:) available=$value ;;
    esac
    [ "$total" -gt 0 ] && [ "$available" -gt 0 ] && break
done < /proc/meminfo

[ "$total" -gt 0 ] || exit 0

used=$(( total - available ))
level=$(( used * LEVELS / total ))
[ "$level" -ge "$LEVELS" ] && level=$(( LEVELS - 1 ))
[ "$level" -lt 0 ] && level=0

case "$level" in
    0) printf '▁\n' ;;
    1) printf '▂\n' ;;
    2) printf '▃\n' ;;
    3) printf '▄\n' ;;
    4) printf '▅\n' ;;
    5) printf '▆\n' ;;
    6) printf '▇\n' ;;
    7) printf '█\n' ;;
esac
