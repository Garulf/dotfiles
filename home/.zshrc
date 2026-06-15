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
source "$HOME/.bashrc"

# Zsh-only aliases and functions
alias tv-audio="pactl set-card-profile 48 output:hdmi-stereo-extra1"
alias default-audio="pactl set-card-profile 48 output:hdmi-stereo"

function ga() {
  if [ "$#" -eq 0 ]; then
    git add -v .
  else
    git add -v "$@"
  fi
}
alias gc="git commit -m"
alias gp="git push"
function gac() { git add -v . && git commit -m "$1" }
function gacp() { gac "$1" && git push }
