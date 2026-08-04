#!/usr/bin/env bash
# ssh-info.sh — discover what the user already has configured.
#
# Usage:
#   ssh-info.sh                 # list every defined alias, note any Includes
#   ssh-info.sh <alias>         # hosts.md row + effective config for that alias
#
# Exit codes:
#   0  ok
#   4  alias is not defined in the config (ask the user; do not guess)
#
# `ssh -G` is the source of truth: it expands Match blocks, Includes, wildcards
# and defaults exactly as ssh will apply them. Never eyeball the config file
# instead — first-match-wins semantics make manual reading error-prone.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

need_ssh

if [ $# -eq 0 ]; then
  [ -r "$SSH_CONFIG" ] || die "No ssh config at $SSH_CONFIG"
  echo "Aliases defined in $SSH_CONFIG:"
  list_aliases | sed 's/^/  /'
  inc="$(include_lines)"
  if [ -n "$inc" ]; then
    echo
    echo "Include directives (their files are covered above):"
    printf '%s\n' "$inc" | sed 's/^/  /'
    echo
    echo "Config files read:"
    config_files | sed 's/^/  /'
  else
    echo
    echo "No Include directives."
  fi
  exit 0
fi

HOST="$1"
require_defined "$HOST"

row="$(hosts_md_row "$HOST")"
if [ -n "$row" ]; then
  echo "hosts.md:"
  printf '%s\n' "$row" | sed 's/^/  /'
  echo
fi

echo "Effective config for '$HOST' (ssh -G):"
mapfile -t fargs < <(ssh_f_args)
ssh "${fargs[@]}" -G "$HOST" 2>/dev/null \
  | grep -Ei '^(hostname|user|port|proxyjump|proxycommand|controlpath|controlmaster|forwardagent|stricthostkeychecking) ' \
  | sed 's/^/  /'

# The identityfile list is mostly OpenSSH's built-in defaults; only the keys
# that actually exist can be offered, so show those and just count the rest.
missing=0
while read -r _ path; do
  expanded="${path/#\~/$HOME}"
  if [ -f "$expanded" ]; then echo "  identityfile $path [present]"; else missing=$((missing + 1)); fi
done < <(ssh "${fargs[@]}" -G "$HOST" 2>/dev/null | grep -Ei '^identityfile ')
[ "$missing" -gt 0 ] && echo "  ($missing further identityfile path(s) configured but not present on disk)"

exit 0
