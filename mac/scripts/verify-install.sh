#!/usr/bin/env bash
# Post-install health check for macOS.
#
# Cross-platform checks live in shared/verify.sh; this file adds only the
# macOS-specific ones. Installs nothing -- safe to run at any time.
#
# Usage:
#   ./run.sh --verify
#   bash scripts/verify-install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
# shellcheck source=../utils/utils.sh
source "$ROOT_DIR/utils/utils.sh"
# shellcheck source=../../shared/verify.sh
source "$REPO_ROOT/shared/verify.sh"

# mise shims and user-local bins are not on PATH in a non-login shell.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.cargo/bin:$PATH"

echo_header "devsetup verification (macOS)"

verify_shared

section "Homebrew"
check_cmd brew
if command -v brew >/dev/null 2>&1; then
    if brew bundle check --file="$ROOT_DIR/Brewfile" >/dev/null 2>&1; then
        ok "Brewfile satisfied"
    else
        warn "Brewfile not fully satisfied  (run: brew bundle install --file=$ROOT_DIR/Brewfile)"
    fi
    # mise must come from ~/.local/bin, not Homebrew: the activation lines in
    # .zshrc and .zprofile reference that exact path.
    if brew list --formula 2>/dev/null | grep -qx mise; then
        warn "mise is also installed via Homebrew  (remove the duplicate: brew uninstall mise)"
    fi
fi

section "macOS-only tools"
check_cmd_optional wezterm
check_cmd_optional docker
check_symlink "$HOME/.config/alacritty"

section "Shell"
# The whole point of initialising Homebrew from .zprofile is that brew's
# binaries beat the macOS system ones, which /etc/zprofile's path_helper
# otherwise undoes. Ask a real login shell -- this script does not run in one,
# so checking our own PATH would report a false failure.
_login_git="$(zsh -lic 'command -v git' 2>/dev/null | tr -d '\r' | tail -1)"
if [[ -z "$_login_git" ]]; then
    warn "could not query a login shell for git resolution"
elif [[ "$_login_git" == /usr/bin/git ]]; then
    warn "login shell resolves git to /usr/bin/git, not Homebrew  (check .zprofile)"
else
    ok "Homebrew binaries take precedence over /usr/bin  ($_login_git)"
fi

if [[ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" == *zsh ]]; then
    ok "login shell is zsh"
else
    warn "login shell is not zsh  (run: ./run.sh --only shell, then log out and back in)"
fi

verify_summary
