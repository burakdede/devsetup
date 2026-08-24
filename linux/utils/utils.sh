#!/usr/bin/env bash

# Common utility functions for setup scripts.

set -o pipefail

# ─── Output ───────────────────────────────────────────────────────────────────
# Rendering lives in shared/ui.sh: colour and boxes only on a terminal, real
# terminal width, and padding by character count so multibyte titles do not
# skew the box. These wrappers keep the historical names so every call site
# throughout the repo works unchanged.
# shellcheck source=../../shared/ui.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/shared/ui.sh"

# Part of this file's public surface: scripts that source it reference the
# colour names directly (scripts/verify-install.sh among others). Exported so
# that stays true for anything they invoke.
export RED="$UI_RED" GREEN="$UI_GREEN" YELLOW="$UI_YELLOW"
export BLUE="$UI_BLUE" CYAN="$UI_CYAN" RESET="$UI_RESET"

echo_header()  { ui_header "${1:-}"; }
log_info()     { ui_info "$1"; }
log_warn()     { ui_warn "$1"; }
log_error()    { ui_err "$1"; }
log_success()  { ui_ok "$1"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_command() {
    command_exists "$1"
}

check_root() {
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        log_error "Run this project as a normal user, not root."
        exit 1
    fi
}

check_directory() {
    if [[ ! -f "run.sh" ]]; then
        log_error "Run this command from the repository root."
        exit 1
    fi
}

ensure_sudo() {
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        return 0
    fi

    if ! sudo -v; then
        log_error "Sudo authentication failed."
        exit 1
    fi
}

# Report a failure with enough context to act on, then stop.
#
# The bare "command failed at line N" this used to print told you nothing about
# which step died or how to pick up where it left off. Steps are independent
# and re-runnable, so the useful thing to say is: what broke, and the exact
# command to resume with.
#
# MACHINIST_STEP is set by run.sh before each step; MACHINIST_ENTRY is set by
# install.sh so the suggested command matches how you invoked it.
handle_error() {
    local exit_code="${1:-$?}"
    local line="${2:-unknown}"
    local script="${BASH_SOURCE[1]:-${0}}"
    local entry="${MACHINIST_ENTRY:-./run.sh}"

    log_error "Failed in $(basename "$script") at line ${line} (exit ${exit_code})."

    if [[ -n "${MACHINIST_STEP:-}" ]]; then
        log_error "Step '${MACHINIST_STEP}' did not complete."
    fi

    log_info ""
    log_info "Nothing has been left half-configured: steps are independent and"
    log_info "safe to re-run. To pick up from here:"
    if [[ -n "${MACHINIST_STEP:-}" ]]; then
        log_info "  ${entry} --only ${MACHINIST_STEP}"
    else
        log_info "  ${entry}"
    fi
    log_info ""
    log_info "To see what is already in place:"
    log_info "  ${entry} --verify"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info ""
        log_info "Full output of this run: ${LOG_FILE}"
    fi

    exit "$exit_code"
}

run_with_output() {
    log_info "Running: $*"
    "$@"
}

sudo_run() {
    ensure_sudo
    log_info "Running with sudo: $*"
    sudo "$@"
}

is_interactive() {
    [[ -t 0 && -t 1 ]]
}

has_desktop_session() {
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

join_by() {
    local separator="$1"
    shift
    local first=1
    local item

    for item in "$@"; do
        if [[ $first -eq 1 ]]; then
            printf '%s' "$item"
            first=0
        else
            printf '%s%s' "$separator" "$item"
        fi
    done
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

read_list_file() {
    local file_path="$1"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue
        printf '%s\n' "$line"
    done < "$file_path"
}

ensure_line_in_file() {
    local line="$1"
    local file_path="$2"

    mkdir -p "$(dirname "$file_path")"
    touch "$file_path"

    if ! grep -Fqx "$line" "$file_path"; then
        printf '%s\n' "$line" >> "$file_path"
    fi
}

load_versions() {
    local versions_file="${1:-}"
    # Default: look for versions.txt at repo root (two levels up from utils/)
    if [[ -z "$versions_file" ]]; then
        local utils_dir
        utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Shared with the other platform -- see packages/versions.txt.
        versions_file="$utils_dir/../../packages/versions.txt"
    fi

    if [[ ! -f "$versions_file" ]]; then
        return 0
    fi

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        # Export so callers can use them
        export "$key"="$value"
    done < "$versions_file"
}

# Compare dotted version strings: version_ge 0.12.3 0.12.0 -> true.
# Uses sort -V, which is present in GNU coreutils and in macOS sort.
version_ge() {
    local have="$1" want="$2"
    [[ -z "$want" ]] && return 0
    [[ "$have" == "$want" ]] && return 0
    [[ "$(printf '%s\n%s\n' "$have" "$want" | sort -V | head -n1)" == "$want" ]]
}

flag_enabled() {
    local value="${1:-0}"
    case "$value" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

# Check MACHINIST_SKIP_<STEP>=1 env var.
# Skip a step: MACHINIST_SKIP_<STEP>=1
#
# The legacy MACHINIST_SKIP_* / MACHINIST_SKIP_* spellings are still honoured
# so older notes and scripts keep working, but MACHINIST_* is the documented
# name and is identical on both platforms.
should_skip_step() {
    local step_name="$1"
    local shared_var="MACHINIST_SKIP_${step_name}"
    local legacy_var="MACHINIST_SKIP_${step_name}"
    flag_enabled "${!shared_var:-${!legacy_var:-0}}"
}

# Force reinstall even when a tool is already present: MACHINIST_UPGRADE=1
# (legacy MACHINIST_UPGRADE is still honoured).
upgrade_enabled() {
    flag_enabled "${MACHINIST_UPGRADE:-0}"
}

backup_gnome_settings() {
    local backup_dir="$HOME/.config/gsettings-backup"
    mkdir -p "$backup_dir"
    gsettings list-recursively > "$backup_dir/settings-backup-$(date +%Y%m%d-%H%M%S).txt"
    log_success "GNOME settings backup created in $backup_dir"
}

restore_gnome_settings() {
    gsettings reset-recursively org.gnome.desktop.wm.preferences
    gsettings reset-recursively org.gnome.desktop.wm.keybindings
    gsettings reset-recursively org.gnome.desktop.interface
    gsettings reset-recursively org.gnome.shell
    gsettings reset-recursively org.gnome.shell.extensions.dash-to-dock
    gsettings reset-recursively org.gnome.shell.extensions
    log_warn "GNOME settings reset. Log out and back in if changes do not appear immediately."
}

show_backup_instructions() {
    cat <<'EOF'
Backup and restore:
  - Backups are stored in ~/.config/gsettings-backup/
  - To reset GNOME settings from a sourced shell, run: restore_gnome_settings
EOF
}
