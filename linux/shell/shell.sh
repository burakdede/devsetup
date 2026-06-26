#!/usr/bin/env bash
# Zsh installation and default shell configuration.
#
# Installs zsh from APT (idempotent), changes the login shell to zsh for the
# current user, and ensures mise activation is wired into ~/.zshrc.
#
# Safe to re-run: every step is guarded by a prior state check.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

ZSH_PROFILE="${ZSH_PROFILE:-antidote-p10k}"
ANTIDOTE_DIR="$HOME/.local/share/antidote"
P10K_DIR="$HOME/.local/share/powerlevel10k"
Z4H_DIR="$HOME/.local/share/zsh4humans"

install_zsh() {
    echo_header "Zsh"

    if command_exists zsh; then
        log_info "zsh is already installed ($(zsh --version 2>/dev/null | head -n1))."
        return 0
    fi

    log_info "Installing zsh..."
    sudo_run apt-get install -y --no-install-recommends zsh
    log_success "zsh installed."
}

set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh 2>/dev/null || true)"

    if [[ -z "$zsh_path" ]]; then
        log_warn "zsh binary not found; cannot set as default shell."
        return 0
    fi

    # Register zsh in /etc/shells if missing
    if ! grep -Fqx "$zsh_path" /etc/shells 2>/dev/null; then
        log_info "Adding $zsh_path to /etc/shells..."
        printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # Check current shell -- skip if already correct
    local current_shell
    current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_info "Default shell is already $zsh_path."
        return 0
    fi

    if command_exists usermod; then
        sudo_run usermod --shell "$zsh_path" "$USER"
        log_success "Default shell changed to $zsh_path (effective after next login)."
    elif command_exists chsh; then
        chsh -s "$zsh_path"
        log_success "Default shell changed to $zsh_path (effective after next login)."
    else
        log_warn "Neither usermod nor chsh found; set default shell manually:"
        log_info "  chsh -s $zsh_path"
    fi
}

wire_mise_activation() {
    # shellcheck disable=SC2016
    local mise_line='eval "$("$HOME/.local/bin/mise" activate zsh)"'
    local zshrc="$HOME/.zshrc"

    # If .zshrc is already a symlink back into our dotfiles repo, the activation
    # line is already present in the source file -- don't append to the repo copy.
    if [[ -L "$zshrc" ]]; then
        log_info "$HOME/.zshrc is a symlink; mise activation line already present in source."
        return 0
    fi

    ensure_line_in_file "$mise_line" "$zshrc"
    log_success "mise activation wired into ~/.zshrc"
}

sync_git_repo() {
    local repo_url="$1"
    local dest_dir="$2"

    if [[ -d "$dest_dir/.git" ]]; then
        if upgrade_enabled; then
            log_info "Upgrading $(basename "$dest_dir")..."
            git -C "$dest_dir" pull --ff-only >/dev/null 2>&1 || log_warn "Could not fast-forward $dest_dir."
        else
            log_info "$(basename "$dest_dir") already present."
        fi
        return 0
    fi

    log_info "Cloning $(basename "$dest_dir")..."
    mkdir -p "$(dirname "$dest_dir")"
    if ! git clone --depth 1 "$repo_url" "$dest_dir" >/dev/null 2>&1; then
        log_warn "Could not clone $repo_url."
    fi
}

install_shell_profile_tools() {
    echo_header "Zsh prompt and plugins"

    case "$ZSH_PROFILE" in
        antidote|antidote-p10k)
            sync_git_repo "https://github.com/mattmc3/antidote.git" "$ANTIDOTE_DIR"
            sync_git_repo "https://github.com/romkatv/powerlevel10k.git" "$P10K_DIR"

            # Pre-bundle plugins so the first shell launch is fast and offline-safe.
            local plugins_txt="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"
            local plugins_zsh="${ZDOTDIR:-$HOME}/.zsh_plugins.zsh"
            if [[ -f "$plugins_txt" && -d "$ANTIDOTE_DIR/functions" ]]; then
                log_info "Pre-bundling zsh plugins with antidote..."
                local clean_txt
                clean_txt="$(mktemp)"
                grep -Ev '^[[:space:]]*(#|$)' "$plugins_txt" > "$clean_txt"
                ANTIDOTE_HOME="$ANTIDOTE_DIR" \
                    zsh -c "fpath=('$ANTIDOTE_DIR/functions' \$fpath); autoload -Uz antidote; antidote bundle < '$clean_txt'" \
                    2>&1 | grep -Ev '^[[:space:]]*warning:' >| "$plugins_zsh" || true
                rm -f "$clean_txt"
                log_success "Plugins bundled to $plugins_zsh"
            fi

            log_success "Configured profile: antidote+p10k"
            ;;
        z4h|zsh4humans)
            sync_git_repo "https://github.com/romkatv/zsh4humans.git" "$Z4H_DIR"
            log_success "Configured profile: zsh4humans"
            ;;
        *)
            log_warn "Unknown LINUX_SETUP_ZSH_PROFILE='$ZSH_PROFILE'. Supported: antidote-p10k, zsh4humans."
            ;;
    esac
}

main() {
    check_root
    export PATH="$HOME/.local/bin:$PATH"

    install_zsh
    set_default_shell
    wire_mise_activation
    install_shell_profile_tools

    echo_header "Shell setup complete"
    log_success "zsh is installed and set as the default shell."
    log_info "Configs: ~/.zshrc  ~/.zshenv  ~/.zprofile"
    log_info "Log out and back in (or start a new session) for the change to take effect."
}

main
