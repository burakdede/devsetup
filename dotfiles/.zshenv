# shellcheck shell=bash
# ~/.zshenv — sourced for every zsh session (interactive, login, and scripts).
#
# Keep this file lean: only set variables that every zsh process needs.
# Interactive customisations belong in ~/.zshrc.

# ─── PATH ─────────────────────────────────────────────────────────────────────
# Homebrew must be initialised before PATH extensions on macOS so that
# brew-managed binaries (zsh, nvim, mise, …) are found first.
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then        # Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then         # Intel
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# User-local binaries (mise, uv, cargo, go, …)
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

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
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
