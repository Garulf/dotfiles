[[ -f "$HOME/.shell_common" ]] && source "$HOME/.shell_common"

# Load functions and aliases
[[ -f "$HOME/.functions" ]] && source "$HOME/.functions"
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# History Behavior
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Auto-attach tmux if appropriate
tmux_shell
