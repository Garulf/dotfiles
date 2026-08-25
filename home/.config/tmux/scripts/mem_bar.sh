#!/bin/sh
# Memory in use as a single vertical bar, tracking pressure rather than raw
# allocation: pages the kernel can hand back on demand don't count as used.
#   Linux:  MemAvailable already accounts for reclaimable cache.
#   Darwin: active + wired + compressor is what Activity Monitor reports as
#           "Memory Used"; inactive and speculative pages stay reclaimable.
# Both branches work in kB so the level math below is shared.
set -eu

LEVELS=8

case "$(uname -s)" in
    Linux)
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
        ;;
    Darwin)
        memsize=$(sysctl -n hw.memsize 2>/dev/null) || exit 0
        [ -n "$memsize" ] && [ "$memsize" -gt 0 ] || exit 0
        total=$(( memsize / 1024 ))

        # vm_stat reports page counts with a trailing period and its page size
        # only in the header, so every figure is scrubbed to digits first
        used=$(vm_stat 2>/dev/null | awk '
            function num(s) { gsub(/[^0-9]/, "", s); return s + 0 }
            /^Mach Virtual Memory Statistics/  { pagesize = num($8) }
            /^Pages active:/                   { active = num($NF) }
            /^Pages wired down:/               { wired = num($NF) }
            /^Pages occupied by compressor:/   { compressed = num($NF) }
            END {
                if (pagesize > 0)
                    printf "%d", (active + wired + compressed) * pagesize / 1024
            }
        ')
        [ -n "$used" ] || exit 0
        ;;
    *)
        exit 0
        ;;
esac

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
