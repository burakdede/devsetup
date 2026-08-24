# shellcheck shell=bash
# ~/.bash_profile -- bash login shells.
#
# zsh is the daily driver here; bash exists for scripts, rescue shells, and
# remote boxes where zsh is not installed. Its job is to behave enough like the
# zsh setup that muscle memory and tooling carry over.
#
# bash reads .bash_profile for LOGIN shells and .bashrc for interactive
# non-login shells. Keeping everything in .bashrc and sourcing it from here
# means there is one file to maintain instead of two that drift apart.

# shellcheck source=.bashrc
[[ -r "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
