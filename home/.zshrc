# Znap bootstrap
[[ -r "$HOME/.znap/znap.zsh" ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git "$HOME/.znap"
zstyle ':znap:*' repos-dir "$HOME/.znap"
source "$HOME/.znap/znap.zsh"

# Plugins
znap source zsh-users/zsh-completions
znap source MichaelAquilina/zsh-auto-notify
znap source Game4Move78/zsh-bitwarden

# Ghost-text autosuggestions: deja (predictive, needs a per-machine binary at
# ~/.local/bin/deja) when present, else fall back to history-based
# zsh-autosuggestions. Only ever one of the two — deja stands down if it
# detects zsh-autosuggestions loaded.
if (( ${+commands[deja]} )); then
  eval "$(deja init zsh)"
else
  znap source zsh-users/zsh-autosuggestions
fi

# Completion initialization
autoload -Uz compinit && compinit

# History options
# HISTSIZE and SAVEHIST are inherited from .profile
HISTFILE="$HOME/.zsh_history"
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS

# Shell options
setopt AUTO_CD
setopt CORRECT
setopt NO_BEEP

# EDITOR="...nvim..." contains "vi", which makes zsh auto-select vi
# keybindings (breaking Ctrl+R history search, etc.) unless forced back to
# emacs bindings here.
bindkey -e

[[ -f "$HOME/.shell_common" ]] && source "$HOME/.shell_common"

[[ -f "$HOME/.functions" ]] && source "$HOME/.functions"
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Auto-attach tmux if appropriate
tmux_shell
[ -f ~/.config/claude/ha.env ] && source ~/.config/claude/ha.env
