#!/usr/bin/env bash
# ssh-doctor.sh — diagnose a failing SSH connection. Read-only: it recommends
# fixes, it never applies them (no known_hosts edits, no config changes).
#
# Usage:
#   ssh-doctor.sh [--timeout N] <host>
#
# Walks the ladder: is the alias defined -> effective config -> each jump hop
# independently -> the connection itself, then classifies ssh's own verbosity
# into one verdict with a specific next move.
#
# Exit codes:
#   0  connection works
#   1  a problem was found (see VERDICT)
#   4  host is not defined in the ssh config
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

TIMEOUT=10
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    -*) DIE_CODE=2 die "unknown option: $1" ;;
    *) break ;;
  esac
done
[ $# -eq 1 ] || { echo "usage: $0 [--timeout N] <host>" >&2; exit 2; }
HOST="$1"

need_ssh

echo "== 1. Is '$HOST' a defined alias?"
require_defined "$HOST"
echo "   yes"

echo
echo "== 2. Effective config"
"$DIR/ssh-info.sh" "$HOST" | sed 's/^/   /'

mapfile -t fargs < <(ssh_f_args)
BASE_OPTS=("${fargs[@]}" -o BatchMode=yes -o "ConnectTimeout=$TIMEOUT")

echo
echo "== 3. Jump chain"
JUMP="$(ssh_opt "$HOST" proxyjump)"
if [ -z "$JUMP" ] || [ "$JUMP" = "none" ]; then
  echo "   no ProxyJump — direct connection"
else
  # Test each hop on its own so a bastion failure isn't misread as the target
  # being down. A forwarding-only bastion refuses `true` but still forwards,
  # so only a connect-level failure counts against it.
  IFS=',' read -ra HOPS <<< "$JUMP"
  for hop in "${HOPS[@]}"; do
    hop="${hop##*@}"
    if ssh "${BASE_OPTS[@]}" "$hop" true >/dev/null 2>&1; then
      echo "   hop '$hop': reachable, shell OK"
    else
      rc=$?
      if [ "$rc" -eq 255 ]; then
        echo "   hop '$hop': UNREACHABLE (exit 255) — fix this hop before looking at '$HOST'"
      else
        echo "   hop '$hop': connects, but the command failed (exit $rc) — normal for a forwarding-only bastion"
      fi
    fi
  done
fi

echo
echo "== 4. Connection test"
ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT
ssh "${BASE_OPTS[@]}" -v "$HOST" true 2>"$ERR"
RC=$?

echo
if [ "$RC" -eq 0 ]; then
  echo "VERDICT: OK — '$HOST' connects and runs commands."
  echo "Next: use ssh-run.sh '$HOST' '<command>'."
  exit 0
fi

if grep -q 'Permission denied (publickey' "$ERR"; then
  echo "VERDICT: publickey denied — the server accepted the connection but rejected every key offered."
  echo "Keys offered:"; grep -E 'Offering public key|Will attempt key' "$ERR" | sed 's/^/   /'
  echo "Next: check the key exists locally (see identityfile above) and that its .pub is in"
  echo "      ~/.ssh/authorized_keys on the remote. Do NOT retry or fall back to password auth."
elif grep -qi 'Host key verification failed\|REMOTE HOST IDENTIFICATION HAS CHANGED' "$ERR"; then
  echo "VERDICT: host key mismatch — the stored key does not match what the host presented."
  echo "Next: this is expected only if the host was rebuilt or reinstalled. CONFIRM WITH THE USER,"
  echo "      then clear that one entry: ssh-keygen -R <hostname>   (never delete known_hosts)"
elif grep -qi 'Host key is not known\|not known and you have requested strict' "$ERR"; then
  echo "VERDICT: unknown host key — first contact with this host."
  echo "Next: have the user connect once manually, or with their OK: ssh-run.sh --accept-new '$HOST' true"
elif grep -qi 'Could not resolve hostname\|Name or service not known' "$ERR"; then
  echo "VERDICT: DNS failure — the hostname does not resolve."
  echo "Next: check the HostName value above; the host may be LAN-only or need a VPN."
elif grep -qi 'Connection timed out\|Operation timed out' "$ERR"; then
  echo "VERDICT: connect timeout — no answer on that host/port."
  echo "Next: host down, firewalled, or wrong port. Check the Port value above."
elif grep -qi 'Connection refused' "$ERR"; then
  echo "VERDICT: connection refused — something answered and said no."
  echo "Next: sshd is likely not running, or is on a different port than configured."
elif grep -qi 'No route to host\|Network is unreachable' "$ERR"; then
  echo "VERDICT: network unreachable — no route to that address from here."
  echo "Next: check VPN / network segment; verify the jump chain above is correct."
elif grep -qi 'channel .*open failed\|administratively prohibited' "$ERR"; then
  echo "VERDICT: the jump host refused to forward."
  echo "Next: check AllowTcpForwarding on the bastion."
elif [ "$RC" -ne 255 ]; then
  echo "VERDICT: connected fine — the remote command itself exited $RC."
  echo "Next: this is not an SSH problem."
  exit 0
else
  echo "VERDICT: connection failed (exit 255), cause not recognised. Last lines of ssh -v:"
  tail -15 "$ERR" | sed 's/^/   /'
  echo "Next: escalate verbosity by hand: ssh -vv (then -vvv) '$HOST' true"
fi

exit 1
