# Tmux auto-attach logic
is_tmux() {
  command -v tmux &>/dev/null &&
    [[ -n "$PS1" ]] &&
    [[ ! "$TERM" =~ screen|tmux ]] &&
    [[ -z "$TMUX" ]]
}

tmux_shell() {
  is_tmux || return
  local session
  session=$(tmux ls 2>/dev/null | grep -v attached | head -1 | cut -d: -f1)
  if [[ -n "$session" ]]; then
    exec tmux attach -t "$session"
  else
    exec tmux
  fi
}
tmux_shell

# Helper functions
function mkd() {
  mkdir -p "$@" && cd "$_"
}

# OS-specific logic
if [ ! $(uname -s) = 'Darwin' ]; then
  if grep -q Microsoft /proc/version; then
    # Ubuntu on Windows using the Linux subsystem
    alias open='explorer.exe'
  else
    alias open='xdg-open'
  fi
fi

function o() {
  if [ $# -eq 0 ]; then
    open .
  else
    open "$@"
  fi
}

function tre() {
  tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX
}

# Git
alias g=git

# General aliases
alias afk='tmux lock-server'
alias ls='ls --color=auto -h -p'
alias ll='ls -l --color=auto -h -p'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec ${SHELL} -l"
alias rel="reload"

alias mpv='mpv --save-position-on-quit'

if command -v nvim &>/dev/null; then
  alias vi="v"
  alias vim="v"
  alias v="vz"
fi

# Editor configs
alias vz="NVIM_APPNAME=nvim-lazyvim nvim"
alias vc="NVIM_APPNAME=nvim-nvchad nvim"

# cd if path is a directory, open nvim
cdv() {
  if [ -d "$1" ]; then
    cd "$1"
  fi
  nvim "$1"
}
