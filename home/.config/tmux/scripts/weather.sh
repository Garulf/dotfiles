#!/bin/sh
# wttr.in's own %c icons are emoji carrying a VS16 variation selector, which
# tmux's width table renders as 1 cell while the terminal renders the emoji
# it modifies as 2 — the glyph overlapped the next character. Nerd Font
# weather glyphs are plain single-width PUA codepoints with no such mismatch,
# so this fetches the numeric WWO condition code via wttr.in's JSON API and
# maps it to one instead of relying on the plugin's emoji output.
set -eu

PATH="/usr/local/bin:$PATH:/usr/sbin"

get_opt() {
    tmux show-option -gqv "$1"
}

set_opt() {
    tmux set-option -gq "$1" "$2"
}

# Nerd Font "weather-*" glyph codepoints (nerd-fonts glyphnames.json).
icon_for_code() {
    case "$1" in
        113) hex=e30d ;;                    # Sunny / Clear (day_sunny)
        116) hex=e302 ;;                    # Partly cloudy (day_cloudy)
        119|122) hex=e312 ;;                # Cloudy / Overcast (cloudy)
        143|248|260) hex=e313 ;;            # Mist / Fog / Freezing fog (fog)
        176|263|266|293|296|299|302|305|308|353|356|359) hex=e318 ;;  # Rain / showers (rain)
        179|182|185|281|284|311|314|317|320|362|365|374|377) hex=e3ad ;;  # Sleet / freezing rain / ice pellets (sleet)
        200|386|389|392|395) hex=e31d ;;    # Thundery (thunderstorm)
        227|230) hex=e35e ;;                # Blowing snow / blizzard (snow_wind)
        323|326|329|332|335|338|368|371) hex=e31a ;;  # Snow / snow showers (snow)
        350) hex=e314 ;;                    # Ice pellets (hail)
        *) hex=e312 ;;                      # Fallback (cloudy)
    esac
    python3 -c "import sys; sys.stdout.write(chr(0x$hex))"
}

location=$(get_opt @tmux-weather-location)
units=$(get_opt @tmux-weather-units)
[ "$units" = "u" ] || units="m"

interval_min=$(get_opt @tmux-weather-interval)
[ -n "$interval_min" ] || interval_min=15
interval=$((interval_min * 60))

now=$(date +%s)
prev=$(get_opt @weather-previous-update-time)
delta=$((now - ${prev:-0}))

if [ -z "$prev" ] || [ "$delta" -ge "$interval" ]; then
    json=$(curl -s --max-time 5 "https://wttr.in/${location}?format=j1" || true)
    if [ -n "$json" ]; then
        code=$(printf '%s' "$json" | jq -r '.current_condition[0].weatherCode' 2>/dev/null || true)
        if [ "$units" = "u" ]; then
            temp=$(printf '%s' "$json" | jq -r '.current_condition[0].temp_F' 2>/dev/null || true)
            unit_symbol="F"
        else
            temp=$(printf '%s' "$json" | jq -r '.current_condition[0].temp_C' 2>/dev/null || true)
            unit_symbol="C"
        fi
        if [ -n "$code" ] && [ -n "$temp" ] && [ "$code" != "null" ] && [ "$temp" != "null" ]; then
            case "$temp" in
                -*) sign="" ;;
                *) sign="+" ;;
            esac
            value="$(icon_for_code "$code") ${sign}${temp}°${unit_symbol}"
            set_opt @weather-previous-update-time "$now"
            set_opt @weather-previous-value "$value"
        fi
    fi
fi

get_opt @weather-previous-value
