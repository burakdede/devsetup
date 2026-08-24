# shellcheck shell=zsh
# ~/.zprofile -- sourced for login shells (SSH, display managers, su -l).
#
# zsh automatically sources .zshenv for ALL shell types (login, interactive,
# non-interactive). There is no need to manually re-source it here.
#
# This file handles the things that must run AFTER the system-wide
# /etc/zprofile: Homebrew initialisation on macOS (see below) and mise shim
# activation for login shells -- covering SSH sessions, cron jobs, and display
# manager sessions that skip .zshrc.

# ─── Homebrew (macOS) ─────────────────────────────────────────────────────────
# Homebrew initialisation MUST happen here, not in ~/.zshenv.
#
# zsh sources files in this order:
#   /etc/zshenv → ~/.zshenv → /etc/zprofile → ~/.zprofile → ~/.zshrc
#
# macOS ships an /etc/zprofile that runs `/usr/libexec/path_helper`, which
# rebuilds PATH from scratch and hoists /usr/bin and /usr/local/bin to the
# front. Because that runs AFTER ~/.zshenv, a `brew shellenv` there is
# silently undone: you end up on Apple's git, curl and zsh even though the
# Homebrew ones are installed. Running it here, after path_helper, is what
# actually makes Homebrew-managed binaries win.
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then        # Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then         # Intel
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# path_helper also demotes the user-local entries set in ~/.zshenv, so
# re-assert them. `typeset -U path` (set in .zshenv) makes this a reorder
# rather than a duplication, and it is a harmless no-op on Linux.
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

# mise: shim mode for login shells (non-interactive; e.g. SSH, cron).
# Interactive shells use `mise activate zsh` (full hooks) in .zshrc instead.
if [[ -x "$HOME/.local/bin/mise" ]]; then
    eval "$("$HOME/.local/bin/mise" activate zsh --shims)"
fi
