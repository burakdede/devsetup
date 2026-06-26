#!/usr/bin/env bash
# WezTerm terminal emulator installation and configuration.
#
# Installs the pinned WezTerm release (see versions.txt) from GitHub.
# Optionally sets WezTerm as the default terminal emulator when a GNOME
# desktop session is active.
#
# Skip:    LINUX_SETUP_SKIP_WEZTERM=1
# Upgrade: LINUX_SETUP_UPGRADE=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

load_versions

# Default falls back to latest release query if versions.txt doesn't pin one
WEZTERM_VERSION="${WEZTERM_VERSION:-}"

installed_wezterm_version() {
    if command_exists wezterm; then
        wezterm --version 2>/dev/null | awk '{print $2}'
    fi
}

resolve_wezterm_download_url() {
    local want="$1"
    local metadata_file="$2"

    local api_url
    if [[ -n "$want" ]]; then
        api_url="https://api.github.com/repos/wez/wezterm/releases/tags/${want}"
    else
        api_url="https://api.github.com/repos/wez/wezterm/releases/latest"
    fi

    local -a auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    if ! curl -sSL --retry 3 --retry-delay 2 "${auth_header[@]}" "$api_url" -o "$metadata_file"; then
        log_warn "Failed to fetch WezTerm release metadata."
        echo ""
        return 0
    fi

    if jq -e '.message' "$metadata_file" &>/dev/null; then
        log_warn "GitHub API error for WezTerm: $(jq -r '.message' "$metadata_file")"
        echo ""
        return 0
    fi

    local url
    # Prefer Ubuntu 24.04 first, then Ubuntu 22.04, then any amd64 .deb, then any .deb.
    url="$(jq -r \
        '.assets[] | select(.name | test("Ubuntu24\\.04\\.deb$")) | .browser_download_url' \
        "$metadata_file" | head -n1)"
    if [[ -z "$url" || "$url" == "null" ]]; then
        url="$(jq -r \
            '.assets[] | select(.name | test("Ubuntu22\\.04\\.deb$")) | .browser_download_url' \
            "$metadata_file" | head -n1)"
    fi
    if [[ -z "$url" || "$url" == "null" ]]; then
        url="$(jq -r \
            '.assets[] | select(.name | test("amd64.*\\.deb$|x86_64.*\\.deb$")) | .browser_download_url' \
            "$metadata_file" | head -n1)"
    fi
    if [[ -z "$url" || "$url" == "null" ]]; then
        url="$(jq -r '.assets[] | select(.name | test("\\.deb$")) | .browser_download_url' "$metadata_file" | head -n1)"
    fi

    if [[ "$url" == "null" ]]; then
        echo ""
    else
        echo "$url"
    fi
}

install_wezterm() {
    echo_header "WezTerm terminal emulator"

    local want="${WEZTERM_VERSION:-}"
    if [[ "$want" == "latest" ]]; then
        want=""
    fi
    local got
    got="$(installed_wezterm_version)"

    if [[ -n "$got" ]] && ! upgrade_enabled; then
        if [[ -z "$want" || "$want" == "nightly" || "$got" == "$want" ]]; then
            log_info "WezTerm $got is already installed. (LINUX_SETUP_UPGRADE=1 to reinstall)"
            return 0
        fi
        log_info "Installed: $got  Pinned: $want -- reinstalling to match pin."
    fi

    local temp_dir deb_path download_url metadata_file
    temp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$temp_dir'" RETURN
    metadata_file="$temp_dir/release.json"

    if [[ -n "$want" ]]; then
        log_info "Resolving WezTerm ${want} (pinned) release asset..."
        download_url="$(resolve_wezterm_download_url "$want" "$metadata_file")"
    else
        log_info "No version pinned -- fetching latest WezTerm release metadata..."
        download_url="$(resolve_wezterm_download_url "" "$metadata_file")"
    fi

    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log_warn "Could not resolve WezTerm download URL. Installation did not run."
        return 1
    fi

    deb_path="$temp_dir/wezterm.deb"
    log_info "Downloading WezTerm package: $download_url"
    curl -fsSL "$download_url" -o "$deb_path"
    sudo_run apt-get install -y "$deb_path"
    rm -rf "$temp_dir"
    log_success "WezTerm installed."
    return 0
}

install_wezterm_desktop_override() {
    # On GNOME/X11 sessions, XMODIFIERS=@im=ibus is injected by im-config.
    # WezTerm's winit backend connects to the iBus XIM server based on this env
    # var before the Lua config is read, causing double key-event processing
    # (duplicate/dropped keystrokes).  use_ime=false in wezterm.lua is not
    # sufficient -- it only prevents IME text composition, not the XIM connection.
    #
    # Fix: user-level .desktop override that launches WezTerm with XMODIFIERS
    # cleared, scoped only to WezTerm so iBus still works for other apps.
    local desktop_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/org.wezfurlong.wezterm.desktop"
    local system_desktop="/usr/share/applications/org.wezfurlong.wezterm.desktop"

    if [[ ! -f "$system_desktop" ]]; then
        log_info "System WezTerm .desktop not found; skipping desktop override."
        return 0
    fi

    mkdir -p "$desktop_dir"
    sed 's|^Exec=wezterm |Exec=env XMODIFIERS= wezterm |' "$system_desktop" > "$desktop_file"
    if command_exists update-desktop-database; then
        update-desktop-database "$desktop_dir" 2>/dev/null || true
    fi
    log_success "WezTerm .desktop override installed (XMODIFIERS cleared for WezTerm)."
}

set_default_terminal() {
    if ! command_exists wezterm; then
        log_warn "WezTerm binary not found; skipping default terminal configuration."
        return 0
    fi

    if ! has_desktop_session; then
        log_info "No desktop session active; skipping default terminal configuration."
        return 0
    fi

    if ! command_exists gsettings; then
        log_info "gsettings not available; skipping default terminal configuration."
        return 0
    fi

    install_wezterm_desktop_override

    log_info "Setting WezTerm as the default GNOME terminal..."
    gsettings set org.gnome.desktop.default-applications.terminal exec 'wezterm'
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg ''

    if command_exists update-alternatives && command_exists wezterm; then
        local wezterm_path
        wezterm_path="$(command -v wezterm)"
        sudo_run update-alternatives --install /usr/bin/x-terminal-emulator \
            x-terminal-emulator "$wezterm_path" 50 || true
        sudo_run update-alternatives --set x-terminal-emulator "$wezterm_path" || true
    fi

    log_success "WezTerm set as default terminal."
}

main() {
    check_root
    export PATH="$HOME/.local/bin:$PATH"

    if ! should_skip_step WEZTERM; then
        if install_wezterm; then
            set_default_terminal
        else
            if command_exists wezterm; then
                log_warn "WezTerm install step failed; keeping existing WezTerm binary and applying default terminal setting."
                set_default_terminal
            else
                log_warn "WezTerm is not installed; default terminal was not changed."
            fi
        fi
    else
        log_info "Skipping WezTerm (LINUX_SETUP_SKIP_WEZTERM is set)."
    fi

    echo_header "Terminal setup complete"
    log_success "WezTerm is ready. Config: ~/.config/wezterm/wezterm.lua"
}

main
