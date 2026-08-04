#!/usr/bin/env bash
# ssh-run.sh — run a command on a remote host without ever hanging on a prompt.
#
# Usage:
#   ssh-run.sh [options] <host> <command...>
#   ssh-run.sh [options] <host>              # reads a script from stdin
#
# Options:
#   --timeout N     connect timeout in seconds (default 10)
#   --accept-new    accept an unknown host key this once (never key *changes*)
#   --tty           allocate a TTY; disables BatchMode, so it can block
#   --no-mux        skip connection multiplexing
#   --adhoc         allow a destination that is not a config alias (only after
#                   the user has supplied the details; never to guess with)
#
# Examples:
#   ssh-run.sh homenas 'uname -a'
#   ssh-run.sh devbox <<'EOF'
#   set -euo pipefail
#   echo "runs remotely, $HOME is remote"
#   EOF
#
# Exit codes:
#   <n>  the remote command's own exit code
#   4    host is not defined in the ssh config
#   255  could NOT connect (or auth failed) — not a command failure
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

CONNECT_TIMEOUT=10
ACCEPT_NEW=0
USE_TTY=0
USE_MUX=1
ADHOC=0

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) CONNECT_TIMEOUT="${2:?--timeout needs a value}"; shift 2 ;;
    --accept-new) ACCEPT_NEW=1; shift ;;
    --tty) USE_TTY=1; shift ;;
    --no-mux) USE_MUX=0; shift ;;
    --adhoc) ADHOC=1; shift ;;
    --) shift; break ;;
    -*) DIE_CODE=2 die "unknown option: $1" ;;
    *) break ;;
  esac
done

[ $# -ge 1 ] || { echo "usage: $0 [options] <host> [command...]" >&2; exit 2; }
HOST="$1"; shift

need_ssh
[ "$ADHOC" -eq 1 ] || require_defined "$HOST"

mapfile -t OPTS < <(ssh_f_args)
OPTS+=(-o "ConnectTimeout=$CONNECT_TIMEOUT")

if [ "$USE_TTY" -eq 1 ]; then
  warn "note: --tty disables BatchMode; this call can block on a prompt."
  OPTS+=(-t)
else
  # Fail fast instead of hanging on a password or confirmation prompt.
  OPTS+=(-o BatchMode=yes)
fi

[ "$ACCEPT_NEW" -eq 1 ] && OPTS+=(-o StrictHostKeyChecking=accept-new)

# Only set up multiplexing if the user's own config doesn't already define it.
if [ "$USE_MUX" -eq 1 ] && [ -z "$(ssh_opt "$HOST" controlpath)" ]; then
  OPTS+=(-o ControlMaster=auto -o "ControlPath=$SSH_DIR/cm-%r@%h:%p" -o ControlPersist=5m)
fi

ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT

# stderr goes to a file first, then straight through — a process substitution
# would race the classification below against tee's flush.
if [ $# -gt 0 ]; then
  ssh "${OPTS[@]}" "$HOST" "$@" 2>"$ERR"
else
  ssh "${OPTS[@]}" "$HOST" 'bash -s' 2>"$ERR"
fi
RC=$?
cat "$ERR" >&2

# 255 is ssh's own failure code. Distinguishing it from a remote command that
# happened to exit 255 is impossible, so report the ambiguity rather than guess.
if [ "$RC" -eq 255 ]; then
  echo "----- ssh exit 255: COULD NOT CONNECT (this is not a remote command failure) -----" >&2
  if grep -q 'Permission denied (publickey' "$ERR"; then
    echo "Key auth is not set up for '$HOST'. Do not retry and do not attempt password auth." >&2
    echo "Report this to the user; see the key distribution section of the ssh-config skill." >&2
  elif grep -qi 'Host key verification failed' "$ERR"; then
    echo "Host key verification failed for '$HOST'. If the host was rebuilt this is expected," >&2
    echo "but confirm with the user before clearing it: ssh-keygen -R <hostname>" >&2
  elif grep -qi 'No route to host\|Network is unreachable\|Connection refused\|Connection timed out\|Operation timed out' "$ERR"; then
    echo "Network-level failure (host down, wrong port, or firewalled). Try: $DIR/ssh-doctor.sh $HOST" >&2
  elif grep -qi 'Could not resolve hostname\|Name or service not known' "$ERR"; then
    echo "DNS could not resolve the hostname for '$HOST'." >&2
  elif grep -qi 'Host key is not known\|not known and you have requested strict' "$ERR"; then
    echo "Unknown host key. Have the user connect once manually, or re-run with --accept-new." >&2
  else
    echo "Diagnose with: $DIR/ssh-doctor.sh $HOST" >&2
  fi
fi

exit "$RC"
