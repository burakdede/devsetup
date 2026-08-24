#!/usr/bin/env bash
# Dotfiles symlinker for Ubuntu.
#
# The logic is OS-neutral and lives in shared/dotfiles.sh. This wrapper only
# supplies the paths. See that file for what gets linked where.
#
# ── Editing a config ──────────────────────────────────────────────────────────
#   $EDITOR ~/Projects/devsetup/dotfiles/.config/nvim/init.lua
#   cd ~/Projects/devsetup && git commit -am "..." && git push
#
# Changes are live immediately -- the installed files are symlinks into the
# repo, so a `git pull` on the other machine is enough. Re-run this step only
# when a NEW dotfile is added and needs a new symlink.
#
# Skip: LINUX_SETUP_SKIP_DOTFILES=1 ./run.sh --only dotfiles

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Consumed by shared/dotfiles.sh, sourced at the bottom of this file.
# shellcheck disable=SC2034
DOTFILES_DIR="$REPO_ROOT/dotfiles"
# shellcheck source=utils/utils.sh
source "$SCRIPT_DIR/utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

# Config dirs outside the shared dotfiles/ tree; consumed by shared/dotfiles.sh.
# shellcheck disable=SC2034
EXTRA_CONFIG_DIRS=""

# shellcheck source=../shared/dotfiles.sh
source "$REPO_ROOT/shared/dotfiles.sh"
install_dotfiles
