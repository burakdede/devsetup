#!/usr/bin/env bash
# Tmux multiplexer setup.
#
# tmux is already listed in system/apt-packages.txt and installed by system.sh.
# This script ensures the XDG-compatible config directory exists so that
# ~/.config/tmux/tmux.conf (installed by dotfiles.sh) is picked up correctly.
#
# tmux 3.1+ reads ~/.config/tmux/tmux.conf when XDG_CONFIG_HOME is set, or
# when ~/.tmux.conf is absent.  We create a compatibility shim for older tmux.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

ensure_tmux_config() {
    echo_header "Tmux"

    if ! command_exists tmux; then
        log_warn "tmux is not installed. Run the system step first."
        return 0
    fi

    local version
    version="$(tmux -V | awk '{print $2}')"
    log_info "tmux version: $version"

    local config_dir="$HOME/.config/tmux"
    mkdir -p "$config_dir"

    # Create a shim ~/.tmux.conf for tmux < 3.1 that just sources the XDG path.
    local shim="$HOME/.tmux.conf"
    local xdg_conf="$config_dir/tmux.conf"
    local shim_line="source-file $xdg_conf"

    if [[ ! -f "$shim" ]]; then
        printf '%s\n' "$shim_line" > "$shim"
        log_info "Created ~/.tmux.conf shim pointing to $xdg_conf"
    else
        ensure_line_in_file "$shim_line" "$shim"
        log_info "Ensured ~/.tmux.conf shim line is present"
    fi

    # Install TPM (Tmux Plugin Manager) into XDG data dir to keep runtime
    # plugin state out of repo-managed dotfiles paths.
    local plugin_root="$HOME/.local/share/tmux/plugins"
    local tpm_dir="$plugin_root/tpm"
    mkdir -p "$plugin_root"
    if [[ ! -d "$tpm_dir" ]] && command_exists git; then
        log_info "Installing TPM (Tmux Plugin Manager)..."
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
        log_success "TPM installed at $tpm_dir"
    elif [[ -d "$tpm_dir" ]]; then
        log_info "TPM is already installed."
    fi

    # Best effort plugin bootstrap so vim-tmux integration works out of the box.
    if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
        "$tpm_dir/bin/install_plugins" >/dev/null 2>&1 || true
    fi

    log_success "Tmux config: $xdg_conf"
}

main() {
    check_root
    ensure_tmux_config
    echo_header "Multiplexer setup complete"
}

main
