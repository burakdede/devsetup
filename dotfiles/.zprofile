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
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do   # Apple Silicon, Intel
        if [[ -x "$_brew" ]]; then
            _evalcache brew "$_brew" "$_brew" shellenv
            break
        fi
    done
    unset _brew
fi

# path_helper also demotes the user-local entries set in ~/.zshenv, so
# re-assert them. `typeset -U path` (set in .zshenv) makes this a reorder
# rather than a duplication, and it is a harmless no-op on Linux.
#
# The mise shims MUST be re-asserted too, and must come before Homebrew above:
# otherwise a login shell picks up Homebrew's node rather than the version
# pinned in the shared mise config. Keep this list in the same order as the
# one in .zshenv.
path=(
    "${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    $path
)

# mise needs nothing here: .zshenv puts the shims directory on PATH for every
# zsh, and .zshrc runs full `mise activate zsh` for interactive ones. This file
# used to shell out to `mise activate --shims`, which was both redundant and a
# subprocess on every login.
