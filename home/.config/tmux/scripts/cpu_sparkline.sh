#!/bin/sh
# Total CPU load over the last few status-interval ticks, as a sparkline.
# Neither sampler may block, since the status bar redraws synchronously.
#   Linux:  /proc/stat is cumulative, so a percentage needs two samples; the
#           previous one is cached rather than taken with a sleep.
#   Darwin: no comparable cheap tick counter exists, so this is run-queue load
#           over core count rather than percent busy. A machine blocked on IO
#           reads high here while its CPUs sit idle.
set -eu

WIDTH=4
LEVELS=8

state="${XDG_RUNTIME_DIR:-/tmp}/tmux-cpu-sparkline.$(id -u)"

prev_total=0
prev_busy=0
history=""
if [ -r "$state" ]; then
    read -r prev_total prev_busy history < "$state" || true
fi

total=0
busy=0
level=""

case "$(uname -s)" in
    Linux)
        read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        busy=$((total - idle - iowait))

        elapsed=$((total - prev_total))
        worked=$((busy - prev_busy))
        if [ "$elapsed" -gt 0 ] && [ "$worked" -ge 0 ]; then
            level=$((worked * LEVELS / elapsed))
        fi
        ;;
    Darwin)
        # vm.loadavg reads "{ 1.85 1.60 1.50 }" and sh has no floats, so awk
        # scales the 1-minute figure to a level in the same pass
        level=$(sysctl -n vm.loadavg hw.ncpu 2>/dev/null | awk -v levels="$LEVELS" '
            NR == 1 { load = $2 }
            NR == 2 { ncpu = $1 }
            END { if (ncpu > 0) printf "%d", load * levels / ncpu }
        ')
        ;;
    *)
        exit 0
        ;;
esac

if [ -n "$level" ]; then
    [ "$level" -ge "$LEVELS" ] && level=$((LEVELS - 1))
    [ "$level" -lt 0 ] && level=0
    history="${history}${level}"
fi

while [ "${#history}" -gt "$WIDTH" ]; do
    history="${history#?}"
done

printf '%s %s %s\n' "$total" "$busy" "$history" > "$state"

while [ "${#history}" -lt "$WIDTH" ]; do
    history="0${history}"
done

bar=""
rest="$history"
while [ -n "$rest" ]; do
    digit="${rest%"${rest#?}"}"
    rest="${rest#?}"
    case "$digit" in
        0) bar="${bar}▁" ;;
        1) bar="${bar}▂" ;;
        2) bar="${bar}▃" ;;
        3) bar="${bar}▄" ;;
        4) bar="${bar}▅" ;;
        5) bar="${bar}▆" ;;
        6) bar="${bar}▇" ;;
        7) bar="${bar}█" ;;
    esac
done

printf '%s\n' "$bar"
