#!/bin/sh
# Total CPU load over the last few status-interval ticks, as a sparkline.
# /proc/stat is cumulative, so a percentage needs two samples; the previous one
# is cached rather than taken with a sleep so the status redraw never blocks.
set -eu

WIDTH=4
LEVELS=8

state="${XDG_RUNTIME_DIR:-/tmp}/tmux-cpu-sparkline.$(id -u)"

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
busy=$((total - idle - iowait))

prev_total=0
prev_busy=0
history=""
if [ -r "$state" ]; then
    read -r prev_total prev_busy history < "$state" || true
fi

elapsed=$((total - prev_total))
worked=$((busy - prev_busy))
if [ "$elapsed" -gt 0 ] && [ "$worked" -ge 0 ]; then
    level=$((worked * LEVELS / elapsed))
    [ "$level" -ge "$LEVELS" ] && level=$((LEVELS - 1))
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
