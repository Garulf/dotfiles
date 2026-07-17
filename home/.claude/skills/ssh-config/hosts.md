# SSH Hosts

Snapshot of hosts defined in `~/.ssh/config`, resolved via `ssh -G` on 2026-07-10.
Check here first for host info; if a host isn't listed (or details look stale), fall back to `~/.ssh/config` / `ssh -G <host>` and update this file.

HostNames, IPs, and ports are intentionally omitted (this file may be publicly viewable) — resolve them locally with `ssh -G <alias>` when needed.

| Alias | User | ProxyJump | OS / Env | Notes |
|---|---|---|---|---|
| `ssh-jump` | garulf | — | Forwarding-only bastion (no-login shell) | Public bastion; all other hosts route through it |
| `homenas` | garulf | ssh-jump | Synology DSM (Linux, DS918+ x86_64) | NAS |
| `devbox` | Garulf | ssh-jump | Debian-based Docker container | Dev container on the NAS (note capital-G user) |
| `mac-mini-m1` | garulf | ssh-jump | macOS 26.x (Apple Silicon / arm64) | Mac mini (M1) |
| `albedo` | garulf | ssh-jump | Windows 11 (cmd.exe default shell) | The ComfyUI Desktop host |
| `phone` | u0_a432 | ssh-jump | Android (Termux) | Android phone (Termux user) |

No `IdentityFile` is pinned for any host — OpenSSH default key paths apply.
No `Include` directives in the config.
