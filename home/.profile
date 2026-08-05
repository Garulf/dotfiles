export PATH="$HOME/.local/bin:$PATH"
export TMOUT=900
export EDITOR="NVIM_APPNAME=nvim-lazyvim nvim"

# Shared History Capacity
export HISTSIZE=5000
export HISTFILESIZE=$HISTSIZE # Bash disk limit
export SAVEHIST=$HISTSIZE     # Zsh disk limit
. "$HOME/.cargo/env"
