#!/usr/bin/env bash
# macOS system bootstrap: Homebrew, Brew packages, mise, Nerd Fonts.
#
# ── Customisation ─────────────────────────────────────────────────────────────
# Packages:  edit Brewfile at the repo root.
# Fonts:     add/remove cask entries with "font-*" in Brewfile.
# mise:      see ~/.config/mise/ for tool version management after install.
#
# To upgrade all packages later:
#   brew upgrade && brew upgrade --cask
#
# To upgrade mise:
#   mise self-update
#
# Skip mise install:   MACSETUP_SKIP_MISE=1 ./run.sh --only system
# Force reinstall:     MACSETUP_UPGRADE=1 ./run.sh --only system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/utils.sh
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BREWFILE="$SCRIPT_DIR/../Brewfile"
UV_TOOLS_FILE="$REPO_ROOT/packages/uv-tools.txt"
NPM_PACKAGES_FILE="$REPO_ROOT/packages/npm-packages.txt"

# Same location as on Linux, so the single activation line in .zshrc and
# .zprofile works on both platforms without OS branching.
MISE_BIN="$HOME/.local/bin/mise"

load_versions

install_homebrew() {
    echo_header "Homebrew"

    if command_exists brew; then
        log_info "Homebrew $(brew --version | head -1) already installed."
        log_info "Updating Homebrew..."
        brew update
        return 0
    fi

    log_info "Installing Homebrew..."
    if ! command_exists xcode-select; then
        log_error "xcode-select not found. Install Xcode Command Line Tools first:"
        log_info "  xcode-select --install"
        exit 1
    fi
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installed."

    # Add Homebrew to current shell PATH (Apple Silicon vs Intel).
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_brew_packages() {
    echo_header "Homebrew packages (Brewfile)"

    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE; skipping."
        return 0
    fi

    # --no-lock was removed from `brew bundle`; lockfile generation no longer
    # exists, so passing it aborts the whole step.
    brew bundle install --file="$BREWFILE"
    brew cleanup -s
    log_success "Homebrew packages installed."
}

install_mise() {
    echo_header "mise (runtime version manager)"

    if should_skip_step MISE; then
        log_info "Skipping mise (MACSETUP_SKIP_MISE is set)."
        return 0
    fi

    # Test for $MISE_BIN specifically, NOT `command -v mise`. A Homebrew-managed
    # mise on PATH would satisfy `command -v` while leaving ~/.local/bin/mise
    # absent, and the activation lines in .zshrc and .zprofile reference that
    # exact path -- so mise would silently never activate.
    local want="${MISE_VERSION:-}"
    local got=""
    [[ -x "$MISE_BIN" ]] && got="$("$MISE_BIN" --version 2>/dev/null | awk '{print $2}')"

    if [[ -n "$got" ]] && ! upgrade_enabled && [[ -z "$want" || "$got" == "$want" ]]; then
        log_info "mise $got is already installed."
    else
        [[ -n "$got" ]] && log_info "mise installed: $got  pinned: ${want:-latest} -- reinstalling."
        log_info "Installing mise ${want:-latest} via official installer..."
        if [[ -n "$want" ]]; then
            MISE_VERSION="$want" curl --proto '=https' --tlsv1.2 -fsSL https://mise.run | sh
        else
            curl --proto '=https' --tlsv1.2 -fsSL https://mise.run | sh
        fi
        log_success "mise installed to $MISE_BIN"
    fi

    # A leftover Homebrew mise is harmless (~/.local/bin precedes /opt/homebrew
    # /bin in PATH) but is a second copy to keep updated. Flag it.
    if brew list --formula 2>/dev/null | grep -qx mise; then
        log_warn "Homebrew also has mise installed. It is no longer in the Brewfile;"
        log_warn "remove the duplicate with: brew uninstall mise"
    fi

    export PATH="$HOME/.local/bin:$PATH"
}

install_mise_runtimes() {
    echo_header "Language runtimes via mise"

    # Versions come from the shared dotfiles/.config/mise/config.toml, so macOS
    # and Ubuntu resolve to the same python/node/go.
    "$MISE_BIN" install
    log_success "Runtimes installed: $("$MISE_BIN" ls --current 2>/dev/null | awk '{printf "%s@%s ", $1, $2}')"
}

# Rust comes from rustup on both platforms rather than from Homebrew, so that
# `rustup component add` / `rustup target add` work the same way on each and
# the toolchain version is pinned from packages/versions.txt.
install_rust() {
    echo_header "Rust via rustup"

    if should_skip_step RUST; then
        log_info "Skipping Rust (MACSETUP_SKIP_RUST is set)."
        return 0
    fi
    if [[ -z "${RUST_VERSION:-}" ]]; then
        log_warn "RUST_VERSION not set in packages/versions.txt; skipping Rust."
        return 0
    fi

    if ! command_exists rustup; then
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
        # shellcheck source=/dev/null
        [[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
    else
        log_info "rustup is already installed."
    fi

    rustup toolchain install "$RUST_VERSION" --profile minimal --no-self-update
    rustup default "$RUST_VERSION"
}

install_uv_tools() {
    echo_header "uv tools"

    if [[ ! -f "$UV_TOOLS_FILE" ]]; then
        log_warn "Missing ${UV_TOOLS_FILE}; skipping uv tools."
        return 0
    fi
    if ! command_exists uv; then
        log_warn "uv not found; skipping uv tools. It is in the Brewfile."
        return 0
    fi

    local package_name
    while IFS= read -r package_name; do
        log_info "Installing uv tool: $package_name"
        uv tool install --quiet "$package_name" || uv tool upgrade "$package_name"
    done < <(read_list_file "$UV_TOOLS_FILE")
}

install_npm_clis() {
    echo_header "Node-based tooling"

    if [[ ! -f "$NPM_PACKAGES_FILE" ]]; then
        log_warn "Missing ${NPM_PACKAGES_FILE}; skipping npm CLIs."
        return 0
    fi

    local package_name
    while IFS= read -r package_name; do
        log_info "Installing npm package: $package_name"
        "$MISE_BIN" exec node -- npm install --global "$package_name"
    done < <(read_list_file "$NPM_PACKAGES_FILE")
}

main() {
    check_root

    install_homebrew
    install_brew_packages
    install_mise
    install_mise_runtimes
    install_rust
    install_uv_tools
    install_npm_clis

    echo_header "System setup complete"
    log_success "Homebrew packages, mise runtimes and CLI tooling are ready."
    log_info "Next: run dotfiles and shell steps."
}

main
