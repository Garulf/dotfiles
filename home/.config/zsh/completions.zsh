# Native shell completions & integrations for installed CLIs, cached per-machine.
#
# Two kinds are handled:
#   1. #compdef scripts autoloaded from fpath. Generated here, BEFORE compinit.
#      Their command is also recorded in $ZSH_COMPDEF_TOOLS so .zshrc can re-bind
#      them with `compdef` after compinit — otherwise a bundled completion that
#      also claims the command (e.g. _sccs claims `delta`) would win.
#   2. eval-style integrations (pip, npm, fzf) that self-register via
#      compctl/compdef or add keybindings. Cached here; SOURCED after compinit.
#
# Each tool emits its own completion, so these track the installed version
# (unlike static copies bundled in completion plugins). A cache is rebuilt only
# when the tool's binary is newer than the cached file, keeping startup cheap.

ZSH_COMPGEN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"  # on fpath
ZSH_COMPEVAL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/integrations"   # sourced later
typeset -ga ZSH_COMPDEF_TOOLS=()   # commands to (re)bind after compinit

() {
  mkdir -p "$ZSH_COMPGEN_DIR" "$ZSH_COMPEVAL_DIR"
  # Prepend so our files win when autoloading a same-named completion function.
  fpath=("$ZSH_COMPGEN_DIR" $fpath)

  # tool -> generator that emits a #compdef script (autoloaded from fpath).
  local -A compdef_gens=(
    docker 'docker completion zsh'
    gh     'gh completion -s zsh'
    uv     'uv generate-shell-completion zsh'
    uvx    'uvx --generate-shell-completion zsh'
    delta  'delta --generate-completion zsh'
    rg     'rg --generate complete-zsh'
    fd     'fd --gen-completions zsh'
  )

  # tool -> generator whose output must be sourced after compinit.
  # (npm is intentionally omitted: its native completion shells out to node per
  # keystroke and self-registers via the compdef that znap stubs out — the
  # system compsys _npm is used instead.)
  local -A eval_gens=(
    pip 'pip completion --zsh'
    fzf 'fzf --zsh'
  )

  local cmd gen bin dst tmp

  for cmd gen in ${(kv)compdef_gens}; do
    (( ${+commands[$cmd]} )) || continue
    bin=${commands[$cmd]}; dst="$ZSH_COMPGEN_DIR/_$cmd"
    if [[ ! -e $dst || $bin -nt $dst ]]; then
      tmp="$dst.tmp"
      # Start at the first #compdef line so compinit reads the tag.
      if eval "$gen" 2>/dev/null | awk '/^#compdef/{p=1} p' > $tmp && [[ -s $tmp ]]; then
        mv $tmp $dst
      else
        rm -f $tmp
      fi
    fi
    [[ -e $dst ]] && ZSH_COMPDEF_TOOLS+=($cmd)
  done

  for cmd gen in ${(kv)eval_gens}; do
    (( ${+commands[$cmd]} )) || continue
    bin=${commands[$cmd]}; dst="$ZSH_COMPEVAL_DIR/$cmd.zsh"
    [[ -e $dst && ! $bin -nt $dst ]] && continue
    tmp="$dst.tmp"
    if eval "$gen" 2>/dev/null > $tmp && [[ -s $tmp ]]; then
      mv $tmp $dst
    else
      rm -f $tmp
    fi
  done
}
