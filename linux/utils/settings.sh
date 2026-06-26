#!/usr/bin/env bash
# Ubuntu System Settings Configuration Script

set -euo pipefail

# Directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils.sh"

trap 'handle_error $? $LINENO' ERR

array_contains() {
    local needle="$1"
    shift

    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done

    return 1
}

# Map extension IDs to their actual gsettings schema names (where they differ from
# the part before @, which is the naive default used in cleanup).
extension_schema_name() {
    local ext="$1"
    case "$ext" in
        just-perfection-desktop@just-perfection) echo "just-perfection" ;;
        AlphabeticalAppGrid@stuarthayhurst)      echo "alphabetical-app-grid" ;;
        *)                                        echo "${ext%@*}" ;;
    esac
}

# Wait until a gsettings schema becomes readable, or time out.
extension_schema_dir() {
    local ext_id="$1"
    local dir="$HOME/.local/share/gnome-shell/extensions/$ext_id/schemas"
    [[ -d "$dir" ]] && printf '%s' "$dir"
}

schema_is_readable() {
    local schema="$1"
    local schema_dir="${2:-}"

    if [[ -n "$schema_dir" ]]; then
        gsettings --schemadir "$schema_dir" list-keys "$schema" &>/dev/null && return 0
    fi
    gsettings list-keys "$schema" &>/dev/null
}

wait_for_schema() {
    local schema="$1"
    local ext_id="${2:-}"
    local schema_dir=""
    local timeout_seconds="${LINUX_SETUP_SCHEMA_WAIT_SECONDS:-60}"
    if [[ -n "$ext_id" ]]; then
        schema_dir="$(extension_schema_dir "$ext_id")"
    fi
    local attempts=0
    while ! schema_is_readable "$schema" "$schema_dir"; do
        (( attempts++ ))
        if (( attempts >= timeout_seconds )); then
            log_warn "Schema $schema not available after ${timeout_seconds} seconds — skipping."
            return 1
        fi
        sleep 1
    done
    return 0
}

set_schema_value() {
    local schema="$1"
    local ext_id="$2"
    local key="$3"
    local value="$4"
    local schema_dir
    schema_dir="$(extension_schema_dir "$ext_id")"

    if [[ -n "$schema_dir" ]] && schema_is_readable "$schema" "$schema_dir"; then
        gsettings --schemadir "$schema_dir" set "$schema" "$key" "$value"
    else
        gsettings set "$schema" "$key" "$value"
    fi
}

resolve_wallpaper_path() {
    local input_path="$1"
    local repo_root="$2"

    if [[ -z "$input_path" ]]; then
        return 1
    fi

    case "$input_path" in
        ~/*)
            printf '%s\n' "$HOME/${input_path#~/}"
            ;;
        /*)
            printf '%s\n' "$input_path"
            ;;
        *)
            printf '%s\n' "$repo_root/$input_path"
            ;;
    esac
}

to_file_uri() {
    local path="$1"
    # Minimal escaping for common local paths.
    printf 'file://%s\n' "${path// /%20}"
}

configure_wallpapers() {
    echo_header "Configuring Wallpapers"
    local repo_root desktop_input login_input desktop_path login_path
    local desktop_uri login_uri login_target login_ext
    local tmp_profile tmp_db

    repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    desktop_input="${LINUX_SETUP_DESKTOP_WALLPAPER_PATH:-assets/wallpapers/desktop.png}"
    login_input="${LINUX_SETUP_LOGIN_WALLPAPER_PATH:-assets/wallpapers/login.png}"

    desktop_path="$(resolve_wallpaper_path "$desktop_input" "$repo_root")"
    if [[ -f "$desktop_path" ]]; then
        desktop_uri="$(to_file_uri "$desktop_path")"
        gsettings set org.gnome.desktop.background picture-uri "$desktop_uri"
        gsettings set org.gnome.desktop.background picture-uri-dark "$desktop_uri"
        gsettings set org.gnome.desktop.background picture-options 'zoom'
        gsettings set org.gnome.desktop.screensaver picture-uri "$desktop_uri"
        gsettings set org.gnome.desktop.screensaver picture-options 'zoom'
        log_success "Desktop wallpaper configured from $desktop_path"
    else
        log_warn "Desktop wallpaper not found at $desktop_path; skipping desktop wallpaper setup."
    fi

    login_path="$(resolve_wallpaper_path "$login_input" "$repo_root")"
    if [[ ! -f "$login_path" ]]; then
        log_warn "Login wallpaper not found at $login_path; skipping login wallpaper setup."
        return 0
    fi

    login_ext="${login_path##*.}"
    login_target="/usr/share/backgrounds/linux-setup-login.${login_ext}"
    login_uri="$(to_file_uri "$login_target")"

    tmp_profile="$(mktemp)"
    tmp_db="$(mktemp)"
    cat > "$tmp_profile" <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

    cat > "$tmp_db" <<EOF
[com/ubuntu/login-screen]
background-picture-uri='${login_uri}'

[org/gnome/desktop/screensaver]
picture-uri='${login_uri}'
EOF

    if ! sudo_run mkdir -p /etc/dconf/profile /etc/dconf/db/gdm.d /usr/share/backgrounds; then
        log_warn "Failed to prepare system directories for login wallpaper."
        rm -f "$tmp_profile" "$tmp_db"
        return 0
    fi
    if ! sudo_run cp "$login_path" "$login_target"; then
        log_warn "Failed to copy login wallpaper to $login_target."
        rm -f "$tmp_profile" "$tmp_db"
        return 0
    fi
    sudo_run chmod 644 "$login_target"
    sudo_run install -m 644 "$tmp_profile" /etc/dconf/profile/gdm
    sudo_run install -m 644 "$tmp_db" /etc/dconf/db/gdm.d/01-background
    if ! sudo_run dconf update; then
        log_warn "Failed to run dconf update for login wallpaper."
        rm -f "$tmp_profile" "$tmp_db"
        return 0
    fi

    rm -f "$tmp_profile" "$tmp_db"
    log_success "Login screen wallpaper configured from $login_path"
}

configure_gnome_extensions() {
    # ========================= Configure GNOME Extensions =========================
    echo_header "Setting up GNOME Extensions"
    log_info "Installing GNOME Extension Manager and pipx..."
    if ! sudo apt-get install -y gnome-shell-extension-manager pipx; then
        log_warn "Failed to install GNOME extension dependencies. Skipping extension setup."
        return 0
    fi

    log_info "Installing gnome-extensions-cli with pipx..."
    if pipx list 2>/dev/null | grep -q "gnome-extensions-cli"; then
        pipx upgrade gnome-extensions-cli 2>/dev/null || true
    else
        pipx install gnome-extensions-cli
    fi
    pipx ensurepath

    export PATH="$PATH:$HOME/.local/bin"

    gext disable tiling-assistant@ubuntu.com || true
    gext disable ubuntu-appindicators@ubuntu.com || true
    gext disable ubuntu-dock@ubuntu.com || true
    gext disable ding@rastersoft.com || true

    local extensions_to_install=(
        "tactile@lundal.io"
        "blur-my-shell@aunetx"
        "just-perfection-desktop@just-perfection"
        "space-bar@luchrioh"
        "undecorate@sun.wxg@gmail.com"
        "tophat@fflewddur.github.io"
        "AlphabeticalAppGrid@stuarthayhurst"
    )

    # Build the list of already-installed extension IDs once for efficiency.
    local installed_exts
    installed_exts="$(gext list 2>/dev/null || true)"

    local ext
    for ext in "${extensions_to_install[@]}"; do
        if echo "$installed_exts" | grep -q "^$ext$"; then
            log_info "Extension already installed, skipping: $ext"
            # Ensure it is enabled even on re-runs.
            gext enable "$ext" 2>/dev/null || true
            continue
        fi

        log_info "Installing extension: $ext"

        if ! gext install "$ext"; then
            log_warn "Failed to install $ext"
            continue
        fi

        sleep 2

        if ! gext enable "$ext"; then
            log_warn "Failed to enable $ext"
            continue
        fi

        sleep 2
        log_success "Successfully installed and enabled: $ext"
    done

    # gext installs schemas into the extension directory under ~/.local — GNOME Shell
    # reads them from there directly. No need to copy to /usr/share or recompile
    # system schemas. Schema availability is checked per-extension before gsettings
    # calls via wait_for_schema below.
    log_info "Extensions installed and enabled."
}

if ! has_desktop_session || ! command_exists gsettings; then
    log_warn "Skipping GNOME settings because no desktop session is active."
    exit 0
fi

# Backup existing settings
backup_gnome_settings

# Show backup and restore instructions
show_backup_instructions

echo_header "Configuring Ubuntu Settings"

# ========================= Configure Display / HiDPI =========================
echo_header "Configuring display scaling (HiDPI)"
# Tuned for dual 27" 4K (3840×2160, ~162 DPI) on X11 with NVIDIA.
#
# GNOME's fractional scaling (scale-monitor-framebuffer) on X11 renders an
# internal 2x framebuffer and downscales — on NVIDIA this causes a significant
# GPU/performance hit at 144 Hz.  The pragmatic X11 approach is:
#   - 1x integer scale (no framebuffer overhead)
#   - text-scaling-factor to bring text to a comfortable size
#   - larger cursor so it's visible at native 4K density
#
# For a proper per-element scaled UI without the performance hit, switch to a
# Wayland session: GNOME on Wayland handles fractional scaling natively at the
# compositor level with no extra rendering cost.
TEXT_SCALE="${LINUX_SETUP_TEXT_SCALE:-1.15}"
CURSOR_SIZE="${LINUX_SETUP_CURSOR_SIZE:-32}"
FONT_RGBA_ORDER="${LINUX_SETUP_FONT_RGBA_ORDER:-rgb}"
FONT_ANTIALIASING="${LINUX_SETUP_FONT_ANTIALIASING:-rgba}"
FONT_HINTING="${LINUX_SETUP_FONT_HINTING:-slight}"
MONOSPACE_FONT="${LINUX_SETUP_MONOSPACE_FONT:-JetBrainsMono Nerd Font 13}"

gsettings set org.gnome.desktop.interface text-scaling-factor "$TEXT_SCALE"
gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE"
gsettings set org.gnome.desktop.interface font-rgba-order "$FONT_RGBA_ORDER"
gsettings set org.gnome.desktop.interface font-antialiasing "$FONT_ANTIALIASING"
gsettings set org.gnome.desktop.interface font-hinting "$FONT_HINTING"
gsettings set org.gnome.desktop.interface monospace-font-name "$MONOSPACE_FONT"

configure_wallpapers

# ========================= Configure Workspace Settings =========================
# This section sets up the multi-workspace environment with 4 workspaces
# and custom keyboard shortcuts for workspace management
echo_header "Setting up Workspaces"

# Configure workspace settings
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 5
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.desktop.wm.preferences workspace-names "['[1] Browse', '[2] Code', '[3] Terminal', '[4] Media', '[5] Other']"

# Configure workspace switching shortcuts
# Set up keyboard shortcuts for switching between workspaces and moving windows
echo "Configuring workspace switching shortcuts..."
for i in {1..5}; do
    # Ctrl + Number: Switch to workspace
    gsettings set "org.gnome.desktop.wm.keybindings" "switch-to-workspace-$i" "['<Control>$i']"
    # Ctrl + Shift + Number: Move active window to workspace
    gsettings set "org.gnome.desktop.wm.keybindings" "move-to-workspace-$i" "['<Control><Shift>$i']"
done

configure_gnome_extensions

# Configure Tactile
if wait_for_schema org.gnome.shell.extensions.tactile tactile@lundal.io; then
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io col-0 1
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io col-1 2
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io col-2 1
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io col-3 0
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io row-0 1
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io row-1 1
    set_schema_value org.gnome.shell.extensions.tactile tactile@lundal.io gap-size 32
fi

# Configure Just Perfection
if wait_for_schema org.gnome.shell.extensions.just-perfection just-perfection-desktop@just-perfection; then
    set_schema_value org.gnome.shell.extensions.just-perfection just-perfection-desktop@just-perfection animation 2
    set_schema_value org.gnome.shell.extensions.just-perfection just-perfection-desktop@just-perfection dash-app-running true
    set_schema_value org.gnome.shell.extensions.just-perfection just-perfection-desktop@just-perfection workspace true
    set_schema_value org.gnome.shell.extensions.just-perfection just-perfection-desktop@just-perfection workspace-popup false
fi

# Configure Blur My Shell
if wait_for_schema org.gnome.shell.extensions.blur-my-shell blur-my-shell@aunetx; then
    set_schema_value org.gnome.shell.extensions.blur-my-shell.appfolder blur-my-shell@aunetx blur false
    set_schema_value org.gnome.shell.extensions.blur-my-shell.lockscreen blur-my-shell@aunetx blur false
    set_schema_value org.gnome.shell.extensions.blur-my-shell.screenshot blur-my-shell@aunetx blur false
    set_schema_value org.gnome.shell.extensions.blur-my-shell.window-list blur-my-shell@aunetx blur false
    set_schema_value org.gnome.shell.extensions.blur-my-shell.panel blur-my-shell@aunetx blur false
    set_schema_value org.gnome.shell.extensions.blur-my-shell.overview blur-my-shell@aunetx blur true
    set_schema_value org.gnome.shell.extensions.blur-my-shell.overview blur-my-shell@aunetx pipeline 'pipeline_default'
    set_schema_value org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur-my-shell@aunetx blur true
    set_schema_value org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur-my-shell@aunetx brightness 0.6
    set_schema_value org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur-my-shell@aunetx sigma 30
    set_schema_value org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur-my-shell@aunetx static-blur true
    set_schema_value org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur-my-shell@aunetx style-dash-to-dock 0
fi

# Configure Space Bar
if wait_for_schema org.gnome.shell.extensions.space-bar space-bar@luchrioh; then
    set_schema_value org.gnome.shell.extensions.space-bar.behavior space-bar@luchrioh smart-workspace-names false
    set_schema_value org.gnome.shell.extensions.space-bar.shortcuts space-bar@luchrioh enable-activate-workspace-shortcuts false
    set_schema_value org.gnome.shell.extensions.space-bar.shortcuts space-bar@luchrioh enable-move-to-workspace-shortcuts true
    set_schema_value org.gnome.shell.extensions.space-bar.shortcuts space-bar@luchrioh open-menu "@as []"
fi

# Configure TopHat
if wait_for_schema org.gnome.shell.extensions.tophat tophat@fflewddur.github.io; then
    set_schema_value org.gnome.shell.extensions.tophat tophat@fflewddur.github.io show-icons true
    set_schema_value org.gnome.shell.extensions.tophat tophat@fflewddur.github.io show-cpu true
    set_schema_value org.gnome.shell.extensions.tophat tophat@fflewddur.github.io show-mem true
    set_schema_value org.gnome.shell.extensions.tophat tophat@fflewddur.github.io show-disk true
    set_schema_value org.gnome.shell.extensions.tophat tophat@fflewddur.github.io network-usage-unit bits
fi

# Configure AlphabeticalAppGrid
if wait_for_schema org.gnome.shell.extensions.alphabetical-app-grid AlphabeticalAppGrid@stuarthayhurst; then
    set_schema_value org.gnome.shell.extensions.alphabetical-app-grid AlphabeticalAppGrid@stuarthayhurst folder-order-position 'end'
fi


# ========================= Configure window manager preferences =========================
echo_header "Configuring window manager preferences..."
# Configure workspace visibility in app switcher and window switcher
gsettings set org.gnome.shell.app-switcher current-workspace-only false
gsettings set org.gnome.shell.window-switcher current-workspace-only false
# Click-to-focus mode (alternative to hover)
gsettings set org.gnome.desktop.wm.preferences focus-mode 'click'
# Raise window when clicked
gsettings set org.gnome.desktop.wm.preferences raise-on-click true
# Disable auto-raise (window raising when mouse hovers)
gsettings set org.gnome.desktop.wm.preferences auto-raise false
# Disable audible bell (beep sound)
gsettings set org.gnome.desktop.wm.preferences audible-bell false

# ========================= Configure Keyboard Shortcuts =========================
echo_header "Configuring keyboard shortcuts..."
# Set Alt+Q to close window
gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>q']"

echo_header "Configuring window management shortcuts..."


# GNOME built-in tiling keybindings (tiling-assistant@ubuntu.com removed from repos;
# Tactile handles grid tiling via its own gsettings above)
gsettings set org.gnome.mutter edge-tiling true
gsettings set org.gnome.desktop.wm.keybindings move-to-side-w "['<Super>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-side-e "['<Super>Right']"
gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']"


# Disable recursive search in Files (nautilus)
gsettings set org.gnome.nautilus.preferences recursive-search 'never'

# ========================= Configure overview shortcuts =========================
echo_header "Configuring overview shortcuts..."
# F2: Toggle overview
gsettings set org.gnome.shell.keybindings toggle-overview "['F2']"
# Super+a: Toggle application view
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>a']"
# Super+v: Toggle message tray
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v']"

# ========================= Configure Dock Settings =========================
echo_header "Configuring Dock Settings"
# Configure dock appearance and behavior
log_info "Configuring dock settings..."
apply_dock_settings() {
    local schema="$1"
    # Set Dock to bottom of the screen
    gsettings set "$schema" dock-position BOTTOM
    # Auto-hide dock
    gsettings set "$schema" dock-fixed false
    # Set icon size to 32
    gsettings set "$schema" dash-max-icon-size 32
    # Show on primary display only
    gsettings set "$schema" multi-monitor false
    # Show applications at top of dock
    gsettings set "$schema" show-apps-at-top true
    # Show favorite applications in dock
    gsettings set "$schema" show-favorites true
    # Show running applications even if not pinned
    gsettings set "$schema" show-running true
    # Show mounted drives in dock
    gsettings set "$schema" show-mounts true
    # Configure auto-hide behavior
    gsettings set "$schema" autohide true
    # Set hide delay (in seconds)
    gsettings set "$schema" hide-delay 0.2
    # Set running indicator style
    gsettings set "$schema" running-indicator-style 'DOTS'
    # Set background opacity
    gsettings set "$schema" background-opacity 0.5
    # Set transparency mode
    gsettings set "$schema" transparency-mode 'FIXED'
    # Set dock not to extend height
    gsettings set "$schema" extend-height false
}

local_dock_configured=0
if schema_is_readable org.gnome.shell.extensions.dash-to-dock; then
    log_info "Applying dock settings to dash-to-dock schema."
    apply_dock_settings org.gnome.shell.extensions.dash-to-dock
    local_dock_configured=1
fi

if schema_is_readable org.gnome.shell.extensions.ubuntu-dock; then
    log_info "Applying dock settings to ubuntu-dock schema."
    apply_dock_settings org.gnome.shell.extensions.ubuntu-dock
    local_dock_configured=1
fi

if [[ "$local_dock_configured" -eq 0 ]]; then
    log_warn "No supported dock schema found (dash-to-dock/ubuntu-dock); skipping dock-specific settings."
fi

# ========================= Screenshot and Recording =========================
echo_header "Screenshot and recording shortcuts..."
# Screenshot Interactively (Shift+Alt+4)
gsettings set org.gnome.shell.keybindings show-screenshot-ui "['<Shift><Alt>4']"
# Screenshot Window (Shift+Alt+3)
gsettings set org.gnome.shell.keybindings screenshot-window "['<Shift><Alt>3']"
# Screenshot (Shift+Alt+2)
gsettings set org.gnome.shell.keybindings screenshot "['<Shift><Alt>2']"
# Screenrecord (Shift+Alt+5)
gsettings set org.gnome.shell.keybindings show-screen-recording-ui "['<Shift><Alt>5']"

# ========================= Dock Favorites =========================
echo_header "Configuring Dock Favorites"

# Define system apps that should always be in the dock
SYSTEM_APPS=(
    'google-chrome.desktop'
    'firefox_firefox.desktop'
    'code.desktop'
    'slack_slack.desktop'
    'discord_discord.desktop'
    'obsidian_obsidian.desktop'
    'localsend_localsend.desktop'
    'obs-studio_obs-studio.desktop'
    'org.gnome.Nautilus.desktop'
    'org.gnome.Terminal.desktop'
    'org.gnome.Settings.desktop'
)

# Get current favorites to preserve any manually added apps
CURRENT_FAVORITES=$(gsettings get org.gnome.shell favorite-apps | tr -d '[]' | tr ',' '\n' | tr -d "' " | grep -v '^$')

# Merge with system apps, removing duplicates
ALL_FAVORITES=("${SYSTEM_APPS[@]}")
while IFS= read -r fav; do
    # Only keep manually added favorites that aren't in our system apps
    # and aren't web apps (we handle those above)
    if ! array_contains "$fav" "${SYSTEM_APPS[@]}"; then
        ALL_FAVORITES+=("$fav")
        log_info "Preserving manually added favorite: $fav"
    fi
done <<< "$CURRENT_FAVORITES"

# Convert array to gsettings format
FAVORITES="$(printf "'%s'," "${ALL_FAVORITES[@]}" | sed 's/,$//')"

# Set the favorites
log_info "Updating dock favorites..."
gsettings set org.gnome.shell favorite-apps "[${FAVORITES}]"

# ========================= Final System Settings =========================
# Set final system-wide settings
log_info "Configuring final system settings..."
# Disable animations for better performance
gsettings set org.gnome.desktop.interface enable-animations false
# Show date in clock
gsettings set org.gnome.desktop.interface clock-show-date true
# Show weekday in clock
gsettings set org.gnome.desktop.interface clock-show-weekday true
# set dark mode by default
gsettings set org.gnome.desktop.interface color-scheme prefer-dark


# ========================= Window & Terminal Behavior =========================
echo_header "Configuring window behavior..."
# Center new windows when launched
gsettings set org.gnome.mutter center-new-windows true
# Configure terminal shortcut
log_info "Configuring terminal shortcut..."
# Set Ctrl+Alt+T as default terminal shortcut
gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Primary><Alt>t']"
# Clear XMODIFIERS for WezTerm so iBus XIM doesn't cause double/dropped keystrokes
gsettings set org.gnome.desktop.default-applications.terminal exec 'env XMODIFIERS= wezterm'


# ========================= Power Management =========================
echo_header "Configuring power management"

# Inactivity timeout before the screen blanks and lock screen activates.
# Configurable via LINUX_SETUP_IDLE_DELAY_SECONDS (0 = never blank).
IDLE_DELAY="${LINUX_SETUP_IDLE_DELAY_SECONDS:-900}"   # default: 15 minutes
gsettings set org.gnome.desktop.session idle-delay "$IDLE_DELAY"

# Lock the screen when the idle delay fires, but do NOT suspend/sleep.
gsettings set org.gnome.desktop.screensaver lock-enabled true
# Show lock screen immediately when blanking (0-second grace period).
gsettings set org.gnome.desktop.screensaver lock-delay 0

# Prevent the system from suspending due to inactivity on AC power.
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
# Same for battery — keeps compute running even when unplugged.
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

log_success "Power management configured: lock screen after ${IDLE_DELAY}s idle, suspend disabled."

log_success "Ubuntu settings configuration completed successfully!"
