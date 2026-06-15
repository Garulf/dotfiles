# Znap bootstrap
[[ -r "$HOME/Repos/znap/znap.zsh" ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git "$HOME/Repos/znap"
source "$HOME/Repos/znap/znap.zsh"

# Plugins
znap source zsh-users/zsh-completions
znap source zsh-users/zsh-autosuggestions
znap source MichaelAquilina/zsh-auto-notify
znap source Game4Move78/zsh-bitwarden

# Completion initialization
autoload -Uz compinit && compinit

# History options
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=5000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS

# Shell options
setopt AUTO_CD
setopt CORRECT
setopt NO_BEEP

# Starship & Zoxide
eval "$(starship init zsh)"
if command -v zoxide > /dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Shared configuration
[[ -f "$HOME/.functions" ]] && source "$HOME/.functions"
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Auto-attach tmux if appropriate
tmux_shell
