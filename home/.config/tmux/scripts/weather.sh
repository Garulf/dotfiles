#!/bin/sh
# Wraps the vendored tmux-weather script and strips the VS16 variation
# selector (U+FE0F) wttr.in's icons carry. tmux's width table renders that
# codepoint as 1 cell while the terminal renders the emoji it modifies as 2,
# so the glyph overlaps the next character and looks squished.
set -eu

/home/Garulf/.config/tmux/plugins/tmux-weather/scripts/weather.sh | sed 's/\xef\xb8\x8f//g'
