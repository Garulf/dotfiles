export PATH="$HOME/.local/bin:$PATH"
# rustup's installer appends this to every shell rc it can find; keep the one
# copy here, where the rest of PATH is set, and guard it for machines without
# a rust toolchain
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export TMOUT=900
export EDITOR="NVIM_APPNAME=nvim-lazyvim nvim"

# Shared History Capacity
export HISTSIZE=5000
export HISTFILESIZE=$HISTSIZE # Bash disk limit
export SAVEHIST=$HISTSIZE     # Zsh disk limit
