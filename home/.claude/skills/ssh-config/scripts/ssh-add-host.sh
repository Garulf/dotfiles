#!/usr/bin/env bash
# ssh-add-host.sh — add a Host block to the ssh config, safely.
#
# Treats the config as production infrastructure: backs up, inserts above any
# wildcard block (ssh uses the FIRST matching value for each option), validates
# with `ssh -G`, checks a pre-existing alias still resolves the same, and
# restores the backup if anything looks wrong.
#
# Usage:
#   ssh-add-host.sh --alias A --hostname H [options]
#
# Options:
#   --user U          remote username
#   --port P          non-standard port
#   --identity F      IdentityFile path
#   --jump J          ProxyJump alias
#   --os "..."        OS / Env column for hosts.md
#   --note "..."      Notes column for hosts.md
#   --dry-run         print the block and insertion point, write nothing
#   --config F        operate on a different config file (for testing)
#   --no-hosts-md     skip the hosts.md row update
#
# Exit codes:
#   0  added and validated
#   2  bad usage
#   3  alias already exists (edit it by hand, with the user watching)
#   5  validation failed — the config was restored from the backup
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

ALIAS=""; HOSTNAME_V=""; USER_V=""; PORT_V=""; IDENTITY_V=""; JUMP_V=""
OS_V=""; NOTE_V=""; DRY_RUN=0; UPDATE_HOSTS_MD=1

while [ $# -gt 0 ]; do
  case "$1" in
    --alias) ALIAS="${2:?}"; shift 2 ;;
    --hostname) HOSTNAME_V="${2:?}"; shift 2 ;;
    --user) USER_V="${2:?}"; shift 2 ;;
    --port) PORT_V="${2:?}"; shift 2 ;;
    --identity) IDENTITY_V="${2:?}"; shift 2 ;;
    --jump) JUMP_V="${2:?}"; shift 2 ;;
    --os) OS_V="${2:?}"; shift 2 ;;
    --note) NOTE_V="${2:?}"; shift 2 ;;
    --config) SSH_CONFIG="${2:?}"; SSH_DIR="$(dirname "$SSH_CONFIG")"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-hosts-md) UPDATE_HOSTS_MD=0; shift ;;
    *) DIE_CODE=2 die "unknown argument: $1" ;;
  esac
done

if [ -z "$ALIAS" ] || [ -z "$HOSTNAME_V" ]; then
  DIE_CODE=2 die "usage: $0 --alias A --hostname H [--user U] [--port P] [--identity F] [--jump J] [--os ...] [--note ...] [--dry-run]"
fi
case "$ALIAS" in *[*?!\ ]*) DIE_CODE=2 die "alias '$ALIAS' must be a plain name (no wildcards or spaces)" ;; esac

need_ssh
[ -r "$SSH_CONFIG" ] || DIE_CODE=2 die "no config at $SSH_CONFIG"

if alias_defined "$ALIAS"; then
  warn "Alias '$ALIAS' already exists in the config."
  warn "Changing an existing block is a manual, eyes-on edit — this script only adds."
  exit 3
fi

BLOCK="Host $ALIAS
    HostName $HOSTNAME_V"
[ -n "$USER_V" ]     && BLOCK="$BLOCK
    User $USER_V"
[ -n "$PORT_V" ]     && BLOCK="$BLOCK
    Port $PORT_V"
[ -n "$IDENTITY_V" ] && BLOCK="$BLOCK
    IdentityFile $IDENTITY_V"
[ -n "$JUMP_V" ]     && BLOCK="$BLOCK
    ProxyJump $JUMP_V"

# Where does it go? A directory Include gets its own file; otherwise the block
# must land ABOVE the first wildcard Host block or that block's options win.
TARGET_FILE="$SSH_CONFIG"
INSERT_LINE=""
INCLUDE_DIR=""
while read -r pattern; do
  case "$pattern" in /*|~*) path="${pattern/#\~/$HOME}" ;; *) path="$(dirname "$SSH_CONFIG")/$pattern" ;; esac
  d="$(dirname "$path")"
  if [ -d "$d" ]; then INCLUDE_DIR="$d"; break; fi
done < <(grep -ihE '^[[:space:]]*Include[[:space:]]' "$SSH_CONFIG" 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}')

if [ -n "$INCLUDE_DIR" ]; then
  TARGET_FILE="$INCLUDE_DIR/$ALIAS.conf"
  PLACEMENT="new file $TARGET_FILE (config uses Include)"
else
  INSERT_LINE="$(awk 'tolower($1)=="host" {for(i=2;i<=NF;i++) if ($i ~ /[*?]/) {print NR; exit}}' "$SSH_CONFIG")"
  if [ -n "$INSERT_LINE" ]; then
    PLACEMENT="$SSH_CONFIG, inserted at line $INSERT_LINE (above the first wildcard Host block)"
  else
    PLACEMENT="$SSH_CONFIG, appended (no wildcard Host block present)"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN — nothing written."
  echo "Placement: $PLACEMENT"
  echo "Block:"
  printf '%s\n' "$BLOCK" | sed 's/^/  /'
  exit 0
fi

# Baseline: a pre-existing alias must resolve identically after the edit.
BASELINE_ALIAS="$(list_aliases | head -1)"
BASELINE=""
if [ -n "$BASELINE_ALIAS" ]; then
  mapfile -t fargs < <(ssh_f_args)
  BASELINE="$(ssh "${fargs[@]}" -G "$BASELINE_ALIAS" 2>/dev/null)"
fi

BACKUP="$SSH_CONFIG.bak.$(date +%s)"
cp -p "$SSH_CONFIG" "$BACKUP" || DIE_CODE=1 die "could not back up $SSH_CONFIG"
echo "Backup: $BACKUP"

restore() {
  cp -p "$BACKUP" "$SSH_CONFIG"
  [ "$TARGET_FILE" != "$SSH_CONFIG" ] && rm -f "$TARGET_FILE"
  warn "Config restored from $BACKUP."
}

if [ "$TARGET_FILE" != "$SSH_CONFIG" ]; then
  printf '%s\n' "$BLOCK" > "$TARGET_FILE"
elif [ -n "$INSERT_LINE" ]; then
  TMP="$(mktemp)"
  head -n "$((INSERT_LINE - 1))" "$SSH_CONFIG" > "$TMP"
  printf '%s\n\n' "$BLOCK" >> "$TMP"
  tail -n "+$INSERT_LINE" "$SSH_CONFIG" >> "$TMP"
  cat "$TMP" > "$SSH_CONFIG"   # preserves the original file's inode and perms
  rm -f "$TMP"
else
  [ -s "$SSH_CONFIG" ] && [ -n "$(tail -c 1 "$SSH_CONFIG")" ] && printf '\n' >> "$SSH_CONFIG"
  printf '\n%s\n' "$BLOCK" >> "$SSH_CONFIG"
fi

chmod 600 "$TARGET_FILE"
chmod 700 "$SSH_DIR"

# Validate: the new alias resolves as intended AND nothing upstream broke.
mapfile -t fargs < <(ssh_f_args)
if ! RESOLVED="$(ssh "${fargs[@]}" -G "$ALIAS" 2>&1)"; then
  warn "ssh -G $ALIAS failed:"; printf '%s\n' "$RESOLVED" >&2
  restore; exit 5
fi
GOT_HOST="$(printf '%s\n' "$RESOLVED" | awk 'tolower($1)=="hostname"{print $2; exit}')"
if [ "$GOT_HOST" != "$HOSTNAME_V" ]; then
  warn "Validation failed: '$ALIAS' resolves to hostname '$GOT_HOST', expected '$HOSTNAME_V'."
  warn "An earlier Host block is probably winning."
  restore; exit 5
fi
if [ -n "$BASELINE_ALIAS" ]; then
  NOW="$(ssh "${fargs[@]}" -G "$BASELINE_ALIAS" 2>/dev/null)"
  if [ "$NOW" != "$BASELINE" ]; then
    warn "Validation failed: pre-existing alias '$BASELINE_ALIAS' now resolves differently."
    diff <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$NOW") >&2 || true
    restore; exit 5
  fi
fi

echo "Added '$ALIAS' to $PLACEMENT"
printf '%s\n' "$BLOCK" | sed 's/^/  /'
echo "Validated: ssh -G $ALIAS resolves as intended; '$BASELINE_ALIAS' unchanged."

# hosts.md deliberately carries no hostname, IP, or port — the file may be
# publicly viewable, so those values are never passed to the row builder.
if [ "$UPDATE_HOSTS_MD" -eq 1 ] && [ -w "$HOSTS_MD" ]; then
  ROW="| \`$ALIAS\` | ${USER_V:-—} | ${JUMP_V:-—} | ${OS_V:-—} | ${NOTE_V:-—} |"
  if hosts_md_row "$ALIAS" >/dev/null; then
    TMP="$(mktemp)"
    awk -v a="$ALIAS" -v row="$ROW" '
      $0 ~ "^\\|[[:space:]]*`?" a "`?[[:space:]]*\\|" { print row; next } { print }
    ' "$HOSTS_MD" > "$TMP" && cat "$TMP" > "$HOSTS_MD" && rm -f "$TMP"
    echo "hosts.md: row for '$ALIAS' updated."
  else
    TMP="$(mktemp)"
    awk -v row="$ROW" '
      /^\|/ { last = NR } { l[NR] = $0 }
      END { for (i = 1; i <= NR; i++) { print l[i]; if (i == last) print row } }
    ' "$HOSTS_MD" > "$TMP" && cat "$TMP" > "$HOSTS_MD" && rm -f "$TMP"
    echo "hosts.md: row added — $ROW"
  fi
fi
