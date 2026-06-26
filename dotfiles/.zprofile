# shellcheck shell=zsh
# ~/.zprofile — sourced for login shells (SSH, display managers, su -l).
#
# zsh automatically sources .zshenv for ALL shell types (login, interactive,
# non-interactive). There is no need to manually re-source it here.
#
# This file's only job is mise shim activation for login shells — covering
# SSH sessions, cron jobs, and display manager sessions that skip .zshrc.

# mise: shim mode for login shells (non-interactive; e.g. SSH, cron).
# Interactive shells use `mise activate zsh` (full hooks) in .zshrc instead.
if [[ -x "$HOME/.local/bin/mise" ]]; then
    eval "$("$HOME/.local/bin/mise" activate zsh --shims)"
fi
