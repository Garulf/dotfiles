#!/usr/bin/env bash
# common.sh — shared helpers for the ssh-config skill scripts.
# Sourced, never executed directly.

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
SSH_CONFIG="${SSH_CONFIG:-$SSH_DIR/config}"
SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HOSTS_MD="${HOSTS_MD:-$SKILL_DIR/hosts.md}"

die() { echo "$*" >&2; exit "${DIE_CODE:-1}"; }
warn() { echo "$*" >&2; }

need_ssh() { command -v ssh >/dev/null || DIE_CODE=127 die "ssh is not installed"; }

# ssh reads ~/.ssh/config unless -F says otherwise. Every ssh invocation in
# these scripts goes through this so a --config override stays consistent.
ssh_f_args() {
  if [ "$SSH_CONFIG" != "$HOME/.ssh/config" ]; then printf '%s\n%s\n' -F "$SSH_CONFIG"; fi
}

# All config files ssh will read: the main file plus anything it Includes.
# Include paths are relative to ~/.ssh and may contain globs.
config_files() {
  [ -r "$SSH_CONFIG" ] || return 0
  printf '%s\n' "$SSH_CONFIG"
  local base; base="$(dirname "$SSH_CONFIG")"
  local pattern path
  while read -r pattern; do
    case "$pattern" in
      /*|~*) path="${pattern/#\~/$HOME}" ;;
      *) path="$base/$pattern" ;;
    esac
    # shellcheck disable=SC2086
    for f in $path; do [ -f "$f" ] && printf '%s\n' "$f"; done
  done < <(grep -ihE '^[[:space:]]*Include[[:space:]]' "$SSH_CONFIG" 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}')
}

include_lines() {
  [ -r "$SSH_CONFIG" ] || return 0
  grep -inE '^[[:space:]]*Include[[:space:]]' "$SSH_CONFIG" 2>/dev/null
}

# Concrete (non-wildcard, non-negated) Host aliases across all config files.
list_aliases() {
  local f
  while read -r f; do
    awk 'tolower($1)=="host" {for(i=2;i<=NF;i++) print $i}' "$f" 2>/dev/null
  done < <(config_files) | grep -vE '[*?!]' | awk 'NF' | awk '!seen[$0]++'
}

alias_defined() { list_aliases | grep -qxF "$1"; }

# One resolved option value, e.g. ssh_opt homenas proxyjump
ssh_opt() {
  local host="$1" key="$2"
  mapfile -t fargs < <(ssh_f_args)
  ssh "${fargs[@]}" -G "$host" 2>/dev/null \
    | awk -v k="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')" \
        'tolower($1)==k {$1=""; sub(/^ /,""); print; exit}'
}

UNDEFINED_HOST_HELP='This host is not defined in the ssh config.

Do NOT guess connection parameters or try them by trial and error. Ask the user for:
  - hostname or IP
  - username (do not assume the local username)
  - port, if non-standard
  - whether it is reached directly or through a jump host they already have
  - which key to use, if they have several

Then offer to add it: ssh-add-host.sh --alias <name> --hostname <host> [--user U] [--jump J]'

require_defined() {
  local host="$1"
  alias_defined "$host" && return 0
  warn "Host '$host' is not a defined alias in $SSH_CONFIG."
  warn ""
  warn "$UNDEFINED_HOST_HELP"
  exit 4
}

hosts_md_row() {
  [ -r "$HOSTS_MD" ] || return 0
  grep -E "^\|[[:space:]]*\`?$1\`?[[:space:]]*\|" "$HOSTS_MD" 2>/dev/null
}
