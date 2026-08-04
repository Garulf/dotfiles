---
name: ssh-config
description: How to read, use, and safely edit the user's SSH client config (~/.ssh/config) when working with remote machines. Use this skill whenever a task involves SSH in any way — running commands on a remote host, copying files with scp/rsync, connecting through a bastion or jump host, adding or modifying a Host entry, debugging a failed connection, generating SSH keys, copying public keys to machines (ssh-copy-id / authorized_keys), or when the user refers to a machine by name (a NAS, a dev box, a server, a VM) that likely resolves through their SSH config. Consult it even if the user doesn't say "ssh config" explicitly.
---

# SSH Config

Operating over SSH from an agent context: discover what the user already has configured, prefer their aliases, never hang on interactive prompts, and edit `~/.ssh/config` without breaking it.

Four scripts own the mechanics. Use them instead of hand-rolling flags — they encode the rules below as behavior and exit codes.

| Script | Use it for |
|---|---|
| `ssh-info.sh [alias]` | List aliases, or resolve one alias's effective config |
| `ssh-run.sh <host> <cmd>` | Run a remote command without hanging; classify failures |
| `ssh-add-host.sh --alias A --hostname H` | Add a Host block with backup, validation, and rollback |
| `ssh-doctor.sh <host>` | Diagnose a connection that isn't working |

Invoke by absolute path — the working directory is not the skill directory. `scripts/` below is shorthand for:

```bash
~/.claude/skills/ssh-config/scripts/
```

Shared exit codes: **3** refused (would need a manual edit), **4** host isn't a defined alias, **5** validation failed and the config was rolled back, **255** could not connect.

## 1. Discover before you connect

**Check `hosts.md` (in this skill's directory) first.** It's a curated index of the user's host aliases — which alias means which machine, users, jump chains, and notes. If the host is listed there, use that alias.

For anything the index deliberately omits (hostnames, IPs, ports) or if it looks stale:

```bash
scripts/ssh-info.sh              # every defined alias, plus any Include files
scripts/ssh-info.sh homenas      # hosts.md row + effective config via ssh -G
```

`ssh -G` is the source of truth — it expands Match blocks, Includes, wildcards, and defaults exactly as ssh will apply them. Never guess what a host resolves to by eyeballing the config file; first-match-wins semantics and wildcard blocks make manual reading error-prone.

**Prefer aliases over raw IPs.** If the user says "the NAS" or "my dev box" and an alias plausibly matches, use the alias — it carries the right user, port, key, and jump chain. If multiple aliases could match, ask rather than guess.

If you turn up a host that's missing from `hosts.md`, add a row for it (alias, user, proxyjump, OS, note — never hostnames, IPs, or ports; the file may be publicly viewable).

**If the host isn't in the config**, `ssh-info.sh` exits 4 and tells you what to ask for. Do not guess connection parameters or try them by trial and error. Get the details from the user, then ask: *"Want me to add this as a Host entry in your ssh config so it's a one-word connect next time?"* If yes, section 3. If no, use `ssh-run.sh --adhoc` for the one-off and don't write to the config.

## 2. Running remote commands

```bash
scripts/ssh-run.sh homenas 'uname -a'

scripts/ssh-run.sh devbox <<'EOF'          # no command arg = script on stdin
set -euo pipefail
echo "runs remotely, $HOME is remote"
EOF
```

It applies `BatchMode=yes` and a connect timeout, reuses a multiplexed connection (unless the user's own config already sets `ControlPath`), and passes the remote command's real exit code straight through.

Options: `--timeout N`, `--accept-new` (accept an unknown host key this once), `--tty` (disables BatchMode, so it can block), `--no-mux`, `--adhoc` (destination that isn't a config alias — only after the user supplied the details).

**Exit 255 means the connection failed, not the command.** The script prints which kind — publickey denied, host key changed, unknown host key, DNS, timeout, refused — with the right next move. On `Permission denied (publickey)`, report it to the user; do not retry in a loop and do not attempt password auth.

`StrictHostKeyChecking=no` is deliberately unreachable from the script: it silences key *changes* too, which defeats MITM protection. `--accept-new` is the scoped opt-in, and only with the user's OK.

For repeated `scp`/`rsync` to the same host, prime the multiplexed connection first with `ssh-run.sh <host> true`; subsequent transfers reuse it. `scp`/`sftp`/`rsync -e ssh` all honor `ProxyJump` from the config — never manually pipe through a bastion the config already chains.

## 3. Adding a host to the config

Treat the config as production infrastructure — a syntax error can lock the user out of everything. Never hand-edit it when this script applies:

```bash
scripts/ssh-add-host.sh --dry-run --alias devbox --hostname 10.0.0.2 --user garulf --port 2222 --jump bastion
scripts/ssh-add-host.sh --alias devbox --hostname 10.0.0.2 --user garulf --port 2222 --jump bastion \
    --os "Debian 12" --note "build box"
```

It backs up to `~/.ssh/config.bak.<epoch>`, writes into the `Include` directory if the config uses one, otherwise inserts **above the first wildcard `Host` block** (ssh uses the first matching value for each option), sets `600`/`700` permissions, then validates: the new alias must resolve to the intended hostname *and* a pre-existing alias must still resolve identically. Any mismatch restores the backup and exits 5. It then mirrors the change into `hosts.md`, with hostname/IP/port structurally excluded from the row.

Always `--dry-run` first and show the user the block and placement.

It refuses (exit 3) if the alias already exists. **Changing or removing an existing block is a manual edit** — back up first, change only what was asked, and never reorder or reformat other blocks: comments and ordering are load-bearing. Re-validate afterwards with `ssh-info.sh` on both the edited alias and one untouched one, and update `hosts.md` by hand.

## 4. Debugging a connection

```bash
scripts/ssh-doctor.sh homenas
```

Read-only — it recommends fixes and never applies them. It checks the alias exists, dumps the effective config, tests each jump hop independently (so a bastion failure isn't misread as the target being down), then classifies `ssh -v` output into one verdict:

| Verdict | Your next move |
|---|---|
| publickey denied | Key auth isn't set up — section 5. Don't retry, don't try passwords. |
| host key mismatch | Confirm with the user it's expected, then `ssh-keygen -R <hostname>` (that one entry only). |
| unknown host key | User connects once manually, or with their OK `ssh-run.sh --accept-new`. |
| DNS failure / timeout / refused / unreachable | Network-level: check HostName, Port, VPN, whether sshd is running. |
| jump host refused to forward | Check `AllowTcpForwarding` on the bastion. |
| unrecognised | Escalate by hand: `ssh -vv` then `-vvv`. |

## 5. Key generation and distribution

When the user needs key auth set up (or `Permission denied (publickey)` reveals it's missing), assist — but every step that touches key material or a remote machine is opt-in. **This section is deliberately not scripted: the confirmations are the point.**

**Generating a key:**

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "user@machine"
```

- Default to ed25519; use `-t rsa -b 4096` only if a legacy device (old NAS firmware, network gear) can't do ed25519.
- **Never overwrite an existing key.** If the default path exists, either reuse it or generate under a new name (e.g. `~/.ssh/id_ed25519_<host>`) and pin it with `--identity` when adding the host block.
- Ask whether they want a passphrase (recommended; mention ssh-agent makes it painless). Don't set an empty passphrase silently.
- `chmod 600` the private key, `chmod 644` the `.pub`.

**Copying the public key to machines — ALWAYS ask first.** Before any copy, state exactly what will happen and get explicit confirmation, e.g.: *"I'll append `id_ed25519.pub` to `~/.ssh/authorized_keys` for user `garulf` on `devbox`. OK to proceed?"* Never batch-copy to multiple hosts under one blanket confirmation — confirm each host.

Once confirmed, prefer `ssh-copy-id` (it handles perms and de-dupes):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <host>
```

If `ssh-copy-id` isn't available or the first connection needs password auth interactively, give the user the command to run themselves rather than trying to script a password prompt. Manual fallback for hosts where you already have some access:

```bash
scripts/ssh-run.sh <host> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < ~/.ssh/id_ed25519.pub
```

Afterwards verify with `scripts/ssh-run.sh <host> true`, and offer to add the host's config block if it isn't there yet.

Only the `.pub` file ever leaves the machine. If anything would transmit or display the private key, stop.

## 6. Security rules

- Never print, cat, or copy private key contents. Referencing paths (`IdentityFile ...`) is fine; displaying key material is not.
- Don't add `ForwardAgent yes` or `PermitLocalCommand` for the user unprompted; explain the risk if they ask for it (agent forwarding lets a compromised remote host use their keys).
- Don't weaken host-key checking globally. Scope any relaxation to the single host in question — `ssh-keygen -R <host>` clears one stale key rather than deleting known_hosts.
- Wrong permissions cause ssh to silently ignore keys or refuse to run: `~/.ssh` is `700`, config and private keys `600`.
