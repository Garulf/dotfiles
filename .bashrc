is_tmux() {
  if command -v tmux &>/dev/null &&
    [ -n "$PS1" ] &&
    [[ ! "$TERM" =~ screen ]] &&
    [[ ! "$TERM" =~ tmux ]] &&
    [ -z "$TMUX" ]; then
    return 0
  else
    return 1
  fi
}

tmux_shell() {
  if is_tmux; then
    echo "Starting tmux..."
    N=$(tmux ls | grep -v attached | head -1 | cut -d: -f1)
    if [[ ! -z $N ]]; then
      exec tmux attach -t $N 2>/dev/null
    else
      exec tmux
    fi
  fi
}
tmux_shell

function mkd() {
  mkdir -p "$@" && cd "$_"
}

# git shortened
alias g=git

# Lock the screen (when going AFK) OSX only
# alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

alias afk='tmux lock-server'

alias ls='ls -G -h -p '
alias ll='ls -l -G -h -p '

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec ${SHELL} -l"
alias rel="reload"
alias ls="command ls $@ -a"

alias mpv='mpv --save-position-on-quit'

if command -v nvim &>/dev/null; then
  alias vi="v"
  alias vim="v"
  alias v="vz"
fi

alias vz="NVIM_APPNAME=nvim-lazyvim nvim"
alias vc="NVIM_APPNAME=nvim-nvchad nvim"

# cd if path is a directory, open nvim
cdv() {
  if [ -d "$1" ]; then
    cd "$1"
  fi
  nvim "$1"
}

# sshs() { ssh $@ -t -- command -v tmux &> /dev/null || screen -R }

#bindkey '^r' history-incremental-search-backward
