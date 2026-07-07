#!/bin/bash
# Claude Code status line.
#
# DIRECTLY REPORTED (read straight from the JSON Claude Code pipes to this
# script on every render): model name, reasoning effort level, the 5-hour
# rate-limit used_percentage/resets_at, and the 7-day ("all models" /
# weekly) rate-limit used_percentage.
#
# DERIVED / ESTIMATED (Claude Code does not expose raw token totals or a
# consumption rate via the status line JSON, so these are computed locally
# by scanning this machine's ~/.claude/projects/**/*.jsonl transcripts):
#   - "ETA"          -> the current 5-hour window's token budget is inferred
#                       by comparing tokens actually seen in that window to
#                       the reported five_hour.used_percentage, then divided
#                       by the token rate observed in the last 30 minutes.
#                       This is an approximation, not an official figure.
#
# The transcript scan is the only "expensive" part; its results are cached
# in $CACHE_FILE for $CACHE_TTL seconds so it only re-runs periodically
# instead of on every prompt render.

input=$(cat)

command -v jq >/dev/null 2>&1 || { printf 'claude (jq not found)'; exit 0; }

model=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"' 2>/dev/null)
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty' 2>/dev/null)
five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
five_resets=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
# Claude Code's JSON only exposes two rate-limit windows: five_hour and
# seven_day. seven_day is the rolling weekly cap that aggregates usage
# across every model on the plan, so it's used here as the "all-model" bar.
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

# ---- ANSI colors (dimmed to fit terminal theme) ----
DIM=$'\033[38;2;108;112;134m'; RESET=$'\033[0m'
CYAN=$'\033[38;2;137;180;250m'; GREEN=$'\033[38;2;166;227;161m'; YELLOW=$'\033[38;2;249;226;175m'; RED=$'\033[38;2;243;139;168m'

# 8-cell block progress bar for a 0-100 percentage.
bar() {
  local pct=${1%%.*} width=8 filled empty i out=""
  [ -z "$pct" ] && pct=0
  case "$pct" in ''|*[!0-9-]*) pct=0 ;; esac
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  for ((i = 0; i < filled; i++)); do out+="█"; done
  for ((i = 0; i < empty; i++)); do out+="░"; done
  printf '%s' "$out"
}

# Color-code a percentage: green < 70, yellow < 90, red >= 90.
color_for_pct() {
  local pct=${1%%.*}
  case "$pct" in ''|*[!0-9-]*) printf '%s' "$GREEN"; return ;; esac
  if [ "$pct" -ge 90 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$pct" -ge 70 ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

# ---- cached transcript scan: weekly / 5h-window / last-30min token sums (derived) ----
CACHE_FILE="$HOME/.claude/.statusline-usage-cache"
CACHE_TTL=60
NOW=$(date +%s)

refresh_cache() {
  local five_start recent_start week_start sums
  week_start=$(( NOW - 604800 ))
  recent_start=$(( NOW - 1800 ))
  if [ -n "$five_resets" ]; then
    five_start=$(( ${five_resets%.*} - 18000 ))
  else
    five_start=$(( NOW - 18000 ))
  fi
  sums=$(find "$HOME/.claude/projects" -type f -name '*.jsonl' -mtime -7 -print0 2>/dev/null \
    | xargs -0 -r cat 2>/dev/null \
    | jq -r 'select(.type=="assistant" and .message.usage) |
        ((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) | tostring) + "\t" +
        (((.message.usage.input_tokens // 0) +
          (.message.usage.output_tokens // 0) +
          (.message.usage.cache_creation_input_tokens // 0) +
          (.message.usage.cache_read_input_tokens // 0)) | tostring)' 2>/dev/null \
    | awk -v w="$week_start" -v f="$five_start" -v r="$recent_start" '
        { t = $1 + 0; tok = $2 + 0
          if (t >= w) week += tok
          if (t >= f) five += tok
          if (t >= r) recent += tok
        }
        END { printf "%d\t%d\t%d\n", week + 0, five + 0, recent + 0 }')
  [ -z "$sums" ] && sums="0	0	0"
  printf '%s\t%s\n' "$NOW" "$sums" > "$CACHE_FILE" 2>/dev/null
  printf '%s\n' "$sums"
}

cache_age=999999
if [ -s "$CACHE_FILE" ]; then
  cached_at=$(cut -f1 "$CACHE_FILE" 2>/dev/null)
  [ -n "$cached_at" ] && cache_age=$(( NOW - cached_at ))
fi

if [ "$cache_age" -ge "$CACHE_TTL" ] 2>/dev/null || [ ! -s "$CACHE_FILE" ]; then
  sums=$(refresh_cache)
else
  sums=$(cut -f2- "$CACHE_FILE" 2>/dev/null)
fi

five_tokens=$(printf '%s' "$sums" | awk -F'\t' '{print $2+0}')
recent_tokens=$(printf '%s' "$sums" | awk -F'\t' '{print $3+0}')

humanize() {
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) printf "%.1fM", n/1000000
    else if (n >= 1000) printf "%.1fK", n/1000
    else printf "%d", n
  }'
}

# ---- ETA until the 5-hour limit is hit, based on the last-30-min token rate (derived) ----
eta_str="-"
if [ -n "$five_pct" ] && [ -n "$five_resets" ] && awk "BEGIN{exit !($five_tokens>0 && $five_pct>0)}" 2>/dev/null; then
  rate_per_min=$(awk -v r="$recent_tokens" 'BEGIN{printf "%.4f", r/30}')
  budget=$(awk -v t="$five_tokens" -v p="$five_pct" 'BEGIN{printf "%.2f", t/(p/100)}')
  remaining=$(awk -v b="$budget" -v t="$five_tokens" 'BEGIN{printf "%.2f", b-t}')
  reset_secs=$(( ${five_resets%.*} - NOW ))
  [ "$reset_secs" -lt 0 ] && reset_secs=0
  if awk "BEGIN{exit !($rate_per_min>0.01)}" 2>/dev/null; then
    eta_min=$(awk -v rem="$remaining" -v rate="$rate_per_min" 'BEGIN{v=rem/rate; if (v<0) v=0; printf "%.0f", v}')
    reset_min=$(( reset_secs / 60 ))
    if [ "$eta_min" -lt "$reset_min" ] 2>/dev/null; then
      if [ "$eta_min" -ge 60 ] 2>/dev/null; then
        eta_str="$(( eta_min / 60 ))h$(( eta_min % 60 ))m"
      else
        eta_str="${eta_min}m"
      fi
    else
      eta_str="resets first"
    fi
  else
    eta_str="idle"
  fi
fi

# ---- 5h reset time in US Eastern (directly reported resets_at, converted) ----
reset_fmt=""
if [ -n "$five_resets" ]; then
  reset_fmt=$(TZ='America/New_York' date -d "@${five_resets%.*}" +'%-I:%M%p %Z' 2>/dev/null)
  reset_secs_disp=$(( ${five_resets%.*} - NOW ))
  [ "$reset_secs_disp" -lt 0 ] && reset_secs_disp=0
  reset_hours=$(( (reset_secs_disp + 1800) / 3600 ))
  if [ "$reset_secs_disp" -lt 3600 ]; then
    reset_hours_fmt="<1h"
  else
    reset_hours_fmt="${reset_hours}h"
  fi
  [ -n "$reset_fmt" ] && reset_fmt="${reset_fmt} (${reset_hours_fmt})"
fi

# ---- assemble output (single line, degrades gracefully if a field is missing) ----
parts=()
parts+=("${CYAN}${model}${RESET}")
[ -n "$effort" ] && parts+=("${DIM}${effort}${RESET}")

if [ -n "$five_pct" ]; then
  c=$(color_for_pct "$five_pct")
  five_pct_fmt=$(printf '%.0f' "$five_pct")
  parts+=("${DIM}5h${RESET} ${c}$(bar "$five_pct")${RESET} ${c}${five_pct_fmt}%${RESET}")
fi

if [ -n "$week_pct" ]; then
  c=$(color_for_pct "$week_pct")
  week_pct_fmt=$(printf '%.0f' "$week_pct")
  parts+=("${DIM}all${RESET} ${c}$(bar "$week_pct")${RESET} ${c}${week_pct_fmt}%${RESET}")
fi

[ -n "$reset_fmt" ] && parts+=("${DIM}resets ${reset_fmt}${RESET}")
[ -n "$five_pct" ] && parts+=("${DIM}ETA ${eta_str}${RESET}")

out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then
    out="$p"
  else
    out="$out ${DIM}|${RESET} $p"
  fi
done
[ -z "$out" ] && out="${CYAN}claude${RESET}"

printf '%s' "$out"
