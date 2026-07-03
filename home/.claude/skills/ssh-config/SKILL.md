---
name: ssh-config
description: How to read, use, and safely edit the user's SSH client config (~/.ssh/config) when working with remote machines. Use this skill whenever a task involves SSH in any way — running commands on a remote host, copying files with scp/rsync, connecting through a bastion or jump host, adding or modifying a Host entry, debugging a failed connection, generating SSH keys, copying public keys to machines (ssh-copy-id / authorized_keys), or when the user refers to a machine by name (a NAS, a dev box, a server, a VM) that likely resolves through their SSH config. Consult it even if the user doesn't say "ssh config" explicitly.
---

# SSH Config

Rules and workflows for operating over SSH from an agent context: discover what the user already has configured, prefer their aliases, never hang on interactive prompts, and edit `~/.ssh/config` without breaking it.

## 1. Discover before you connect

Before running any `ssh`/`scp`/`rsync` command against a remote host, learn what's already configured:

```bash
# List defined host aliases (skip wildcards)
grep -E "^Host " ~/.ssh/config | grep -v "[*?]"

# Check for included config fragments
grep -iE "^Include" ~/.ssh/config
# If present, read those files too (paths are relative to ~/.ssh/)
```

Resolve the *effective* config for a host — this expands Match blocks, Includes, wildcards, and defaults exactly as ssh will apply them:

```bash
ssh -G <host> | grep -Ei "^(hostname|user|port|identityfile|proxyjump|proxycommand|controlpath|forwardagent)"
```

`ssh -G` is the source of truth. Never guess what a host resolves to by eyeballing the config file — first-match-wins semantics and wildcard blocks make manual reading error-prone.

**Prefer aliases over raw IPs.** If the user says "the NAS" or "my dev box" and an alias plausibly matches, use the alias — it carries the right user, port, key, and jump chain. If multiple aliases could match, ask rather than guess.

### When the host isn't in the config

If the host the user mentioned doesn't match any alias (and `ssh -G` just echoes it back with defaults), **do not guess or try connection parameters by trial and error**. Instead, ask the user for the missing pieces:

- Hostname or IP
- Username (don't assume the local username)
- Port, if non-standard
- Whether it's reached directly or through a jump host they already have configured
- Which key to use, if they have several

Then ask: **"Want me to add this as a Host entry in your ssh config so it's a one-word connect next time?"** If yes, follow section 5 (Editing safely). If no, use the details for a one-off command and move on — don't write to the config without an explicit yes.

## 2. Running remote commands non-interactively

An agent cannot answer password prompts or host-key confirmations. Every scripted SSH invocation should be prompt-proof:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 <host> '<command>'
```

- `BatchMode=yes` makes ssh fail fast instead of hanging on a password prompt. If it fails with "Permission denied", key auth isn't set up — report that to the user; do not retry in a loop or attempt password auth.
- For a brand-new host, the host-key prompt will block. Either tell the user to connect once manually, or (only with their OK) use `-o StrictHostKeyChecking=accept-new`. Never use `StrictHostKeyChecking=no` — it also silences key *changes*, which defeats MITM protection.
- Quote carefully: single-quote the remote command so local shell expansion doesn't mangle it. For multi-line remote scripts, use a quoted heredoc:

```bash
ssh <host> 'bash -s' <<'EOF'
set -euo pipefail
echo "runs remotely, $HOME is remote"
EOF
```

- Check exit codes: `ssh host 'cmd'` propagates the remote exit code. A timeout/connection failure returns 255 — distinguish "command failed" from "couldn't connect".
- Allocate a TTY (`-t`) only when the remote command genuinely needs one (e.g. `sudo` with password, interactive tools). Never combine `-t` with BatchMode expectations.

## 3. Multiplexing for repeated commands

If a task requires several commands against the same host, don't pay the handshake (and jump-chain) cost every time. Open a control master once:

```bash
ssh -o ControlMaster=auto -o ControlPath=~/.ssh/cm-%r@%h:%p -o ControlPersist=5m <host> true
# Subsequent ssh/scp/rsync to <host> with the same ControlPath reuse the connection
```

Check whether the user's config already sets `ControlMaster`/`ControlPath` (via `ssh -G`) — if so, just use plain `ssh` and it multiplexes automatically. Clean up with `ssh -O exit -o ControlPath=... <host>` if you started a persistent master the config didn't define.

## 4. Jump hosts and multi-hop

- One-off: `ssh -J bastion target` (chains allowed: `-J hop1,hop2`).
- Persistent: `ProxyJump bastion` inside the target's Host block.
- `scp`/`sftp`/`rsync -e ssh` all honor ProxyJump from the config — never manually pipe through the bastion when the config already defines the chain.
- To debug a multi-hop failure, test each hop independently: `ssh bastion true`, then `ssh -J bastion target true`.

## 5. Editing ~/.ssh/config safely

Treat the config as production infrastructure — a syntax error can lock the user out of everything.

**Procedure:**
1. Back up first: `cp ~/.ssh/config ~/.ssh/config.bak.$(date +%s)`
2. Understand ordering: **ssh uses the first matching value for each option**. Specific `Host` blocks must appear *before* wildcard blocks like `Host *`. Never append a specific host after a `Host *` block that overrides the options you're setting — insert it above instead.
3. If the config uses `Include ~/.ssh/config.d/*` (or similar), prefer adding a new file in that directory over editing the main file.
4. Add complete, minimal blocks:

```
Host devbox
    HostName 10.0.0.2
    Port 2222
    User garulf
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump bastion
```

5. Validate after editing: `ssh -G <new-host>` must succeed and show the intended values. Also re-check one *pre-existing* alias to confirm nothing upstream broke.
6. Never reorder, reformat, or "clean up" existing blocks unless asked — comments and ordering are load-bearing.

**Permissions matter:** if you create files, set `chmod 600 ~/.ssh/config` and key files, `chmod 700 ~/.ssh`. Wrong permissions cause ssh to silently ignore keys or refuse to run.

## 6. Key generation and distribution

When the user needs key auth set up (or `Permission denied (publickey)` reveals it's missing), assist — but every step that touches key material or a remote machine is opt-in.

**Generating a key:**

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "user@machine"
```

- Default to ed25519; use `-t rsa -b 4096` only if a legacy device (old NAS firmware, network gear) can't do ed25519.
- **Never overwrite an existing key.** If the default path exists, either reuse it or generate under a new name (e.g. `~/.ssh/id_ed25519_<host>`) and pin it with `IdentityFile` in that host's config block.
- Ask whether they want a passphrase (recommended; mention ssh-agent makes it painless). Don't set an empty passphrase silently.
- `chmod 600` the private key, `chmod 644` the `.pub`.

**Copying the public key to machines — ALWAYS ask first.** Before any copy, state exactly what will happen and get explicit confirmation, e.g.: *"I'll append `id_ed25519.pub` to `~/.ssh/authorized_keys` for user `garulf` on `devbox`. OK to proceed?"* Never batch-copy to multiple hosts under one blanket confirmation — confirm each host.

Once confirmed, prefer `ssh-copy-id` (it handles perms and de-dupes):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <host>
```

If `ssh-copy-id` isn't available or the first connection needs password auth interactively, give the user the command to run themselves rather than trying to script a password prompt. Manual fallback for hosts where you already have some access:

```bash
cat ~/.ssh/id_ed25519.pub | ssh <host> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Afterwards, verify non-interactively: `ssh -o BatchMode=yes <host> true` — and offer to add/update the host's config block if it isn't there yet.

Only the `.pub` file ever leaves the machine. If anything would transmit or display the private key, stop.

## 7. Security rules

- Never print, cat, or copy private key contents. Referencing paths (`IdentityFile ...`) is fine; displaying key material is not.
- Don't add `ForwardAgent yes` or `PermitLocalCommand` for the user unprompted; explain the risk if they ask for it (agent forwarding lets a compromised remote host use their keys).
- Don't weaken host-key checking globally. Scope any relaxation (`accept-new`, known_hosts edits) to the single host in question, e.g. `ssh-keygen -R <host>` to clear one stale key rather than deleting known_hosts.

## 8. Troubleshooting quick reference

| Symptom | First move |
|---|---|
| Hangs silently | `ssh -o ConnectTimeout=5 -v <host> true` — network/port vs auth |
| `Permission denied (publickey)` | `ssh -G <host> \| grep identityfile`; check the key exists and is offered (`ssh -v`), check remote `authorized_keys` |
| `Host key verification failed` | Key changed — confirm with user it's expected, then `ssh-keygen -R <hostname>` |
| Alias resolves wrong host/user | `ssh -G <alias>` and look for an earlier wildcard block winning |
| Works interactively, fails in script | Interactive prompt being suppressed — rerun with `BatchMode=yes -v` to see what's asked |
| Slow connect on every command | Set up multiplexing (section 3) or check for DNS timeout (`UseDNS`, broken reverse lookup) |
| ProxyJump chain fails | Test each hop separately; check the bastion allows TCP forwarding (`AllowTcpForwarding`) |

Escalate verbosity gradually: `-v` → `-vv` → `-vvv`. The relevant line is usually near the last "Authentications that can continue" or the first "debug1: connect" failure.
