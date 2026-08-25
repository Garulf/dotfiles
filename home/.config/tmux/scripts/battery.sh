#!/bin/sh
# Battery charge as a Nerd Font glyph plus percentage. tmux-battery is
# installed, but it substitutes #{battery_*} into status strings at tpm load
# time, which happens before status-right is set further down tmux.conf, so
# this reads the platform sources directly the same way weather.sh does.
# Glyphs are Font Awesome codepoints (U+F240-F244 battery tiers, U+F0E7 bolt),
# written literally rather than built per tick like weather.sh's rarer icons.
set -eu

PATH="/usr/local/bin:$PATH:/usr/sbin"

percent=""
state=""

case "$(uname -s)" in
    Darwin)
        batt=$(pmset -g batt 2>/dev/null) || exit 0
        percent=$(printf '%s\n' "$batt" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)%.*/\1/p' | head -n 1)
        case "$batt" in
            *"; charging;"*) state=charging ;;
        esac
        ;;
    Linux)
        if command -v termux-battery-status >/dev/null 2>&1; then
            json=$(termux-battery-status 2>/dev/null) || exit 0
            percent=$(printf '%s' "$json" |
                sed -n 's/.*"percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
            case "$json" in
                *CHARGING*) state=charging ;;
            esac
        else
            for supply in /sys/class/power_supply/BAT*; do
                [ -r "$supply/capacity" ] || continue
                percent=$(cat "$supply/capacity")
                if [ "$(cat "$supply/status" 2>/dev/null)" = "Charging" ]; then
                    state=charging
                fi
                break
            done
        fi
        ;;
    *)
        exit 0
        ;;
esac

case "$percent" in
    ''|*[!0-9]*) exit 0 ;;
esac

if [ "$state" = charging ]; then
    icon=""
elif [ "$percent" -ge 90 ]; then
    icon=""
elif [ "$percent" -ge 65 ]; then
    icon=""
elif [ "$percent" -ge 40 ]; then
    icon=""
elif [ "$percent" -ge 15 ]; then
    icon=""
else
    icon=""
fi

printf '%s %s%%\n' "$icon" "$percent"
