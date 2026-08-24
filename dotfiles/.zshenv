# shellcheck shell=bash
# ~/.zshenv -- sourced for every zsh session (interactive, login, and scripts).
#
# Keep this file lean: only set variables that every zsh process needs.
# Interactive customisations belong in ~/.zshrc.

# ─── PATH ─────────────────────────────────────────────────────────────────────
# Homebrew is NOT initialised here -- see ~/.zprofile for why.
#
# Keep PATH free of duplicate entries.
#
# This file is sourced by EVERY zsh process, and the setup deliberately nests
# login shells: WezTerm spawns "$SHELL -l", and tmux spawns "$SHELL -l" again
# for each pane. Without this, every nesting level re-prepends the entries
# below and PATH grows without bound.
#
# macOS papers over this because /etc/zprofile runs /usr/libexec/path_helper,
# which rebuilds and de-duplicates PATH. Ubuntu has no equivalent for zsh, so
# make the behaviour explicit and identical on both platforms.
typeset -U path PATH

# User-local binaries (mise, uv, cargo, go, …).
#
# Set here rather than in .zprofile so that non-interactive shells
# (`zsh -c ...`, `ssh host <command>`, cron) can find them too. Precedence is
# re-asserted in .zprofile; see the note there.
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

# ─── XDG base directories ─────────────────────────────────────────────────────
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ─── Default applications ─────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# ─── Less ─────────────────────────────────────────────────────────────────────
export LESS="-R --quit-if-one-screen"

# ─── Language / locale ────────────────────────────────────────────────────────
# LANG only, as a fallback for systems that set nothing.
#
# LC_ALL is deliberately NOT set. It overrides every LC_* category at once and
# outranks LANG, so forcing it here silently discards the region you picked in
# System Settings or localectl -- an en_GB machine would still get US date and
# number formats. Set LC_ALL per-command when you need to pin one, e.g.
# `LC_ALL=C sort`.
export LANG="${LANG:-en_US.UTF-8}"
