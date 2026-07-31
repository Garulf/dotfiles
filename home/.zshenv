# .zshenv is sourced by EVERY zsh (login/non-login, interactive or not),
# unlike .zshrc/.shell_common which only run for interactive shells.
#
# Claude Code spawns login, NON-interactive zsh shells that source a captured
# function snapshot (which includes zoxide's `cd`/doctor) but never register
# zoxide's chpwd hook or export _ZO_DOCTOR. Those shells therefore trip
# zoxide's "detected a possible configuration issue" doctor warning on the
# first `cd`. Silencing it here guarantees the flag is set before any snapshot
# runs, in every shell regardless of how it was launched (e.g. `claude rc`).
export _ZO_DOCTOR=0
