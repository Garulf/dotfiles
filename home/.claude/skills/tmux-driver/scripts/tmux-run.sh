#!/usr/bin/env bash
# tmux-run.sh — run a command inside a tmux session, wait for it to finish
# (up to a timeout), then print its output and exit code.
#
# Usage:
#   tmux-run.sh <session> <timeout-seconds> <command string>
#
# Examples:
#   tmux-run.sh claude-build 600 'cargo build --release'
#   tmux-run.sh claude-deps 120 'uv pip install -r requirements.txt'
#
# Behavior:
#   - Creates the session (detached, 220x50) if it doesn't exist.
#   - Refuses (exit 3) if the pane is busy running something else.
#   - Runs the command, waits via `tmux wait-for` with a timeout.
#   - On completion: prints THIS command's output; exits with its exit code.
#   - On timeout: prints output so far, notes the command is STILL RUNNING
#     (it keeps running in the session), and exits 124. Re-check later with:
#       tmux capture-pane -t '=<session>:' -p -J -S -
set -u

if [ $# -lt 3 ]; then
  echo "usage: $0 <session> <timeout-seconds> <command string>" >&2
  exit 2
fi

SESSION="$1"; TIMEOUT="$2"; shift 2
CMD="$*"

command -v tmux >/dev/null || { echo "tmux is not installed" >&2; exit 127; }

# Create session if missing. Wide pane avoids line-wrapping in captured output.
tmux has-session -t "=$SESSION" 2>/dev/null || \
  tmux new-session -d -s "$SESSION" -x 220 -y 50

# NOTE: pane-targeting commands need '=name:' (trailing colon) for exact match.
T="=$SESSION:"

# Refuse to type into a busy pane.
CUR="$(tmux display-message -t "$T" -p '#{pane_current_command}')"
case "$CUR" in
  bash|zsh|sh|dash|fish|ksh) : ;;  # idle shell, good
  *)
    echo "Pane in '$SESSION' is busy running '$CUR'. Current output:" >&2
    tmux capture-pane -t "$T" -p -J | awk 'NF{n=NR} {l[NR]=$0} END{for(i=1;i<=n;i++)print l[i]}' >&2
    echo "(Use a different session name, or interrupt it with: tmux send-keys -t '$T' C-c)" >&2
    exit 3
    ;;
esac

CHAN="claude_done_$$_$RANDOM"
EC_FILE="$(mktemp)"

# Send the command literally (-l) so quoting inside $CMD survives, then Enter.
tmux send-keys -t "$T" -l "{ $CMD ; }; echo \$? > $EC_FILE; tmux wait-for -S $CHAN"
tmux send-keys -t "$T" Enter

# Print only output that appeared after this command was echoed at the prompt
# (the $CHAN string uniquely marks the command line), minus trailing blanks.
show_output() {
  tmux capture-pane -t "$T" -p -J -S - | awk -v m="$CHAN" '
    index($0, m) { start = NR }
    { l[NR] = $0 }
    END { for (i = start + 1; i <= NR; i++) if (i <= NR) print l[i] }
  ' | awk 'NF{n=NR} {l[NR]=$0} END{for(i=1;i<=n;i++)print l[i]}'
}

if timeout "$TIMEOUT" tmux wait-for "$CHAN"; then
  echo "----- output ($SESSION) -----"
  show_output
  EC="$(cat "$EC_FILE" 2>/dev/null || echo 1)"
  rm -f "$EC_FILE"
  echo "----- exit code: $EC -----"
  exit "$EC"
else
  echo "----- TIMEOUT after ${TIMEOUT}s — command STILL RUNNING in session '$SESSION' -----"
  show_output
  rm -f "$EC_FILE"
  exit 124
fi
