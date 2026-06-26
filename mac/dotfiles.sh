#!/usr/bin/env bash
# Dotfiles symlinker for macOS.
#
# Creates symlinks from $HOME (and $HOME/.config) to the shared dotfiles
# that live in the repo's top-level dotfiles/ directory.  Editing files
# there is immediately reflected everywhere — no copy step needed.
#
# ── Shared dotfiles ───────────────────────────────────────────────────────────
# dotfiles/ is at the repository root, shared between mac/ and linux/.
# A config change committed there takes effect on both machines after a
# `git pull` — no submodule bumping required.
#
# To edit a config:
#   $EDITOR ~/Projects/devsetup/dotfiles/.config/nvim/init.lua
#   cd ~/Projects/devsetup && git commit -am "..." && git push
#
# ── What this script does ─────────────────────────────────────────────────────
# 1. Backs up any existing non-symlink files before overwriting them.
# 2. Symlinks each top-level dotfile (.*) in dotfiles/ → $HOME/
# 3. Symlinks each .config sub-directory individually (never symlinks
#    ~/.config itself — other tools own entries there).
# 4. Symlinks macOS-only configs from mac/configs/.config/ → $HOME/.config/
#
# Safe to re-run: idempotent.
#
# Skip:    MACSETUP_SKIP_DOTFILES=1 ./run.sh --only dotfiles

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"
# shellcheck source=utils/utils.sh
source "$SCRIPT_DIR/utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

BACKUP_ROOT="$HOME/.local/state/devsetup/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

backup_target() {
    local target="$1"
    local relative="${target#"$HOME"/}"
    local backup_path="$BACKUP_ROOT/$relative"

    [[ ! -e "$target" && ! -L "$target" ]] && return 0

    # Skip symlinks already pointing into our dotfiles dir.
    # Use plain readlink (not -f) — macOS BSD readlink does not support -f.
    if [[ -L "$target" ]] && \
       [[ "$(readlink "$target" 2>/dev/null)" == "$DOTFILES_DIR"* ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$backup_path")"
    cp -a "$target" "$backup_path"
}

link_path() {
    local source_path="$1"
    local target_path="$2"

    backup_target "$target_path"
    mkdir -p "$(dirname "$target_path")"
    rm -rf "$target_path"
    ln -sf "$source_path" "$target_path"
    log_success "Linked $(basename "$target_path")"
}

install_config_entries() {
    local config_source="$DOTFILES_DIR/.config"
    local config_target="$HOME/.config"

    [[ -d "$config_source" ]] || return 0

    mkdir -p "$config_target"

    shopt -s dotglob nullglob
    local item
    for item in "$config_source"/*; do
        local name
        name="$(basename "$item")"
        link_path "$item" "$config_target/$name"
    done
    shopt -u dotglob nullglob
}

install_home_dotfiles() {
    shopt -s dotglob nullglob
    local path
    for path in "$DOTFILES_DIR"/*; do
        local name
        name="$(basename "$path")"

        # Skip the .config sub-directory (handled separately above).
        [[ "$name" == ".config" ]] && continue
        # Skip the repo's own .gitignore — it's internal to the dotfiles repo.
        # The global gitignore is .gitignore_global (referenced in .gitconfig).
        [[ "$name" == ".gitignore" ]] && continue

        link_path "$path" "$HOME/$name"
    done
    shopt -u dotglob nullglob
}

install_macos_configs() {
    # macOS-specific .config entries that are NOT in the shared dotfiles directory.
    # Add any macOS-only tool configs here (e.g. alacritty, iTerm2 dynamic profiles).
    local macos_config="$SCRIPT_DIR/configs/.config"
    [[ -d "$macos_config" ]] || return 0

    local config_target="$HOME/.config"
    mkdir -p "$config_target"

    shopt -s dotglob nullglob
    local item
    for item in "$macos_config"/*; do
        local name
        name="$(basename "$item")"
        link_path "$item" "$config_target/$name"
    done
    shopt -u dotglob nullglob
}

main() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "dotfiles/ directory not found at $DOTFILES_DIR"
        log_info "Ensure you cloned the full repo: git clone git@github.com:burakdede/devsetup.git"
        exit 1
    fi

    echo_header "Dotfiles"
    mkdir -p "$BACKUP_ROOT"

    install_home_dotfiles
    install_config_entries
    install_macos_configs   # alacritty and other macOS-only configs

    mkdir -p "$HOME/.git_template"
    log_success "Created ~/.git_template (required by init.templateDir in .gitconfig)"
    log_info "Backups (if any) stored in $BACKUP_ROOT"
}

main
