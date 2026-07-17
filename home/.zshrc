# Znap bootstrap
[[ -r "$HOME/.znap/znap.zsh" ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git "$HOME/.znap"
zstyle ':znap:*' repos-dir "$HOME/.znap"
source "$HOME/.znap/znap.zsh"

# Plugins
znap source zsh-users/zsh-completions
znap source zsh-users/zsh-autosuggestions
znap source MichaelAquilina/zsh-auto-notify
znap source Game4Move78/zsh-bitwarden

# Native CLI completions (docker, gh, uv, ...) — must load before compinit
[[ -f "$HOME/.config/zsh/completions.zsh" ]] && source "$HOME/.config/zsh/completions.zsh"

# Completion initialization
autoload -Uz compinit && compinit

# Register generated CLI completions. This container's world-writable $HOME makes
# compinit skip our (insecure) fpath dir, so it neither autoloads our functions
# nor maps them (tools with no system fallback like uv/rg get nothing, and
# `delta` is hijacked by system _sccs). So do both explicitly: autoload the
# function from fpath, and set _comps directly — the latter also bypasses znap's
# compdef stub, which drops calls after compinit (same reason _proj does this).
for _c in $ZSH_COMPDEF_TOOLS; do
  autoload -Uz _$_c
  _comps[$_c]=_$_c
done
unset _c

# Eval-style completions/integrations cached by completions.zsh (need compinit
# first: pip/npm self-register via compctl/compdef, fzf adds keybindings).
if [[ -n "$ZSH_COMPEVAL_DIR" ]]; then
  for _f in "$ZSH_COMPEVAL_DIR"/*.zsh(N); do source "$_f"; done
  unset _f
fi

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
