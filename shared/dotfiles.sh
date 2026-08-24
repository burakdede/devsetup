#!/usr/bin/env bash
# Dotfile symlinking -- shared by macOS and Ubuntu.
#
# This file contains no OS-specific logic. It is sourced by mac/dotfiles.sh and
# linux/dotfiles.sh, which may set EXTRA_CONFIG_DIRS to a list of additional
# directories whose entries should also be linked into ~/.config (macOS uses
# this for mac/configs/.config).
#
# ── What it does ──────────────────────────────────────────────────────────────
# 1. Backs up any existing non-symlink file before replacing it.
# 2. Symlinks each top-level dotfile in dotfiles/ -> $HOME/
# 3. Symlinks each dotfiles/.config/* entry individually. It never symlinks
#    ~/.config itself, because other tools own entries in there.
#
# Safe to re-run: idempotent.

BACKUP_ROOT="$HOME/.local/state/devsetup/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

backup_target() {
    local target="$1"
    local relative="${target#"$HOME"/}"
    local backup_path="$BACKUP_ROOT/$relative"

    [[ ! -e "$target" && ! -L "$target" ]] && return 0

    # Skip symlinks already pointing into our dotfiles dir.
    #
    # Plain readlink, not `readlink -f`: BSD readlink on macOS has no -f, and
    # the links we create point directly at $DOTFILES_DIR, so reading one level
    # is both sufficient and portable.
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

# Link every entry of $1 into ~/.config/.
link_config_entries() {
    local config_source="$1"
    local config_target="$HOME/.config"

    [[ -d "$config_source" ]] || return 0
    mkdir -p "$config_target"

    shopt -s dotglob nullglob
    local item name
    for item in "$config_source"/*; do
        name="$(basename "$item")"
        link_path "$item" "$config_target/$name"
    done
    shopt -u dotglob nullglob
}

install_home_dotfiles() {
    shopt -s dotglob nullglob
    local path name
    for path in "$DOTFILES_DIR"/*; do
        name="$(basename "$path")"

        # Handled separately by link_config_entries.
        [[ "$name" == ".config" ]] && continue
        # The dotfiles dir's own .gitignore is internal to this repo. The global
        # gitignore is .gitignore_global, referenced from .gitconfig.
        [[ "$name" == ".gitignore" ]] && continue
        # macOS drops these into any directory Finder has visited.
        [[ "$name" == ".DS_Store" ]] && continue

        link_path "$path" "$HOME/$name"
    done
    shopt -u dotglob nullglob
}

install_dotfiles() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "dotfiles/ directory not found at $DOTFILES_DIR"
        log_info "Ensure you cloned the full repo: git clone git@github.com:burakdede/devsetup.git"
        exit 1
    fi

    echo_header "Dotfiles"
    mkdir -p "$BACKUP_ROOT"

    install_home_dotfiles
    link_config_entries "$DOTFILES_DIR/.config"

    # Platform-specific config dirs, e.g. mac/configs/.config.
    local extra
    for extra in ${EXTRA_CONFIG_DIRS:-}; do
        link_config_entries "$extra"
    done

    mkdir -p "$HOME/.git_template"
    log_success "Created ~/.git_template (required by init.templateDir in .gitconfig)"
    log_info "Backups (if any) stored in $BACKUP_ROOT"
}
