#!/usr/bin/env bash
# Neovim installation and system integration.
#
# Downloads the pinned stable Neovim release (see versions.txt) from GitHub,
# installs it to /usr/local/bin/nvim, and registers it with update-alternatives
# so that `vim`, `vi`, and `editor` all resolve to nvim.
#
# Skip:    LINUX_SETUP_SKIP_NEOVIM=1
# Upgrade: LINUX_SETUP_UPGRADE=1  (re-installs even if nvim is present)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

load_versions

NVIM_INSTALL_DIR="/usr/local"
NVIM_BIN="$NVIM_INSTALL_DIR/bin/nvim"
# Default falls back to latest if versions.txt doesn't pin one
NEOVIM_VERSION="${NEOVIM_VERSION:-}"

installed_nvim_version() {
    if command_exists nvim; then
        nvim --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//'
    fi
}

install_neovim() {
    echo_header "Neovim"

    local want="${NEOVIM_VERSION:-}"
    if [[ "$want" == "latest" ]]; then
        want=""
    fi
    local got
    got="$(installed_nvim_version)"

    if [[ -n "$got" ]] && ! upgrade_enabled; then
        if [[ -z "$want" || "$got" == "$want" ]]; then
            log_info "Neovim $got is already installed. (LINUX_SETUP_UPGRADE=1 to reinstall)"
            return 0
        fi
        log_info "Installed: $got  Pinned: $want — reinstalling to match pin."
    fi

    log_info "Installing Neovim build dependencies..."
    sudo_run apt-get install -y --no-install-recommends \
        build-essential cmake gettext ninja-build unzip curl

    local temp_dir download_url archive_path
    temp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$temp_dir'" RETURN

    # Build the asset URL directly from the pinned version (no API call needed).
    # Falls back to querying the GitHub API for the latest release when no version is pinned.
    if [[ -n "$want" ]]; then
        local tag="v${want}"
        local asset="nvim-linux-x86_64.tar.gz"
        download_url="https://github.com/neovim/neovim/releases/download/${tag}/${asset}"
        log_info "Downloading Neovim ${want} (pinned)..."
    else
        log_info "No version pinned — fetching latest Neovim release metadata..."
        local metadata_file="$temp_dir/release.json"
        curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/latest" \
            -o "$metadata_file"
        if jq -e '.message' "$metadata_file" &>/dev/null; then
            log_warn "GitHub API error: $(jq -r '.message' "$metadata_file"). Skipping."
            return 0
        fi
        download_url="$(jq -r \
            '.assets[] | select(.name | test("nvim-linux-x86_64\\.tar\\.gz$")) | .browser_download_url' \
            "$metadata_file" | head -n1)"
    fi

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log_warn "Could not resolve Neovim download URL. Skipping."
        return 0
    fi

    archive_path="$temp_dir/nvim.tar.gz"
    curl -fsSL "$download_url" -o "$archive_path"

    log_info "Extracting and installing Neovim to $NVIM_INSTALL_DIR ..."
    tar -xzf "$archive_path" -C "$temp_dir"
    local extracted_dir
    extracted_dir="$(find "$temp_dir" -maxdepth 1 -type d -name 'nvim-*' | head -n1)"

    if [[ -z "$extracted_dir" ]]; then
        log_warn "Could not find extracted Neovim directory. Skipping."
        return 0
    fi

    sudo_run cp -rf "$extracted_dir/bin/."   "$NVIM_INSTALL_DIR/bin/"
    sudo_run cp -rf "$extracted_dir/lib/."   "$NVIM_INSTALL_DIR/lib/"   2>/dev/null || true
    sudo_run cp -rf "$extracted_dir/share/." "$NVIM_INSTALL_DIR/share/" 2>/dev/null || true
    sudo_run chmod 0755 "$NVIM_BIN"

    rm -rf "$temp_dir"
    log_success "Neovim $(installed_nvim_version) installed to $NVIM_BIN"
}

register_alternatives() {
    if [[ ! -x "$NVIM_BIN" ]]; then
        log_warn "$NVIM_BIN not found; skipping update-alternatives registration."
        return 0
    fi

    log_info "Registering Neovim with update-alternatives..."

    sudo_run update-alternatives --install /usr/bin/vim    vim    "$NVIM_BIN" 60
    sudo_run update-alternatives --set             vim            "$NVIM_BIN"

    sudo_run update-alternatives --install /usr/bin/vi     vi     "$NVIM_BIN" 60
    sudo_run update-alternatives --set             vi             "$NVIM_BIN"

    sudo_run update-alternatives --install /usr/bin/editor editor "$NVIM_BIN" 60
    sudo_run update-alternatives --set             editor         "$NVIM_BIN"

    log_success "vim, vi, and editor now resolve to nvim."
}

bootstrap_plugins() {
    if ! command_exists nvim; then
        log_warn "nvim not found; skipping plugin bootstrap."
        return 0
    fi

    local nvim_config="$HOME/.config/nvim/init.lua"
    if [[ ! -f "$nvim_config" ]]; then
        log_warn "$HOME/.config/nvim/init.lua not found; run dotfiles step first."
        return 0
    fi

    log_info "Bootstrapping Neovim plugins (headless)..."
    nvim --headless "+Lazy! sync" +qa 2>&1 | grep -v "^$" || true
    log_success "Neovim plugins installed."
}

main() {
    check_root
    ensure_sudo
    export PATH="$HOME/.local/bin:$PATH"

    if ! should_skip_step NEOVIM; then
        install_neovim
        register_alternatives
        bootstrap_plugins
    else
        log_info "Skipping Neovim (LINUX_SETUP_SKIP_NEOVIM is set)."
    fi

    echo_header "Editor setup complete"
    log_success "Neovim is ready. Config: ~/.config/nvim/"
}

main
