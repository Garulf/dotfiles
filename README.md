# Dotfiles

## Structure

- `home/`: Configuration files managed by `GNU Stow`.
- `activate.sh`: Main entry point for syncing and applying changes.

## Shell Loading Order

1. `.profile`: Environment variables and generic shell settings.
2. `.zprofile`: Sources `.profile` (login shells).
3. `.bashrc` / `.zshrc`: Main interactive configuration and aliases.

## Custom Commands

- `proj <name>`: Opens (creating if needed) `~/projects/<name>` in a tmux split with `claude` and `$EDITOR`. Tab-completes existing project directories.

## Quick Start

To activate these dotfiles on a new machine:

```bash
./activate.sh
```
