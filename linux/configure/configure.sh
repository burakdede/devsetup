#!/usr/bin/env bash
# Interactive configuration step.
#
# Prompts for anything that cannot have a machine-independent default:
#   - Git identity (name + email) — written to ~/.gitconfig.local so the
#     symlinked ~/.gitconfig stays clean and uncommitted.
#
# Safe to re-run: existing values are shown as defaults; pressing Enter keeps them.
# Non-interactive environments (CI, piped stdin) are detected and skipped.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

LOCAL_GITCONFIG="$HOME/.gitconfig.local"
PROMPT_TIMEOUT_SECONDS="${LINUX_SETUP_PROMPT_TIMEOUT_SECONDS:-60}"

# ── Helpers ───────────────────────────────────────────────────────────────────

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    local prompt_out="/dev/stderr"
    local prompt_in=""
    # Use /dev/tty only for true interactive sessions.
    # In tests/CI, stdin may be piped input; prefer stdin there.
    if [[ -t 0 && -r /dev/tty && -w /dev/tty ]]; then
        prompt_out="/dev/tty"
        prompt_in="/dev/tty"
    fi

    if [[ -n "$default" ]]; then
        printf '%s [%s]: ' "$prompt" "$default" > "$prompt_out"
    else
        printf '%s: ' "$prompt" > "$prompt_out"
    fi

    if [[ "${PROMPT_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] && [[ "$PROMPT_TIMEOUT_SECONDS" -gt 0 ]]; then
        if [[ -n "$prompt_in" ]]; then
            if ! read -r -t "$PROMPT_TIMEOUT_SECONDS" result < "$prompt_in"; then
                printf '\n' > "$prompt_out"
                log_warn "Input timed out after ${PROMPT_TIMEOUT_SECONDS}s."
                result=""
            fi
        elif ! read -r -t "$PROMPT_TIMEOUT_SECONDS" result; then
            printf '\n' > "$prompt_out"
            log_warn "Input timed out after ${PROMPT_TIMEOUT_SECONDS}s."
            result=""
        fi
    else
        if [[ -n "$prompt_in" ]]; then
            read -r result < "$prompt_in" || result=""
        else
            read -r result || result=""
        fi
    fi
    if [[ -z "$result" ]]; then
        printf '%s' "$default"
    else
        printf '%s' "$result"
    fi
}

git_local_get() {
    git config --file "$LOCAL_GITCONFIG" "$1" 2>/dev/null || true
}

git_global_get() {
    # Read from all levels except the local override file itself to get
    # whatever is currently configured (from system .gitconfig).
    git config --global "$1" 2>/dev/null || true
}

# ── Git identity ──────────────────────────────────────────────────────────────

configure_git_identity() {
    echo_header "Git identity"

    # Current values: local override takes precedence, then global
    local current_name current_email
    current_name="$(git_local_get user.name || git_global_get user.name)"
    current_email="$(git_local_get user.email || git_global_get user.email)"

    # Non-interactive/automated seeding support.
    if [[ -n "${LINUX_SETUP_GIT_NAME:-}" ]]; then
        current_name="${LINUX_SETUP_GIT_NAME}"
    fi
    if [[ -n "${LINUX_SETUP_GIT_EMAIL:-}" ]]; then
        current_email="${LINUX_SETUP_GIT_EMAIL}"
    fi

    if [[ -n "${LINUX_SETUP_GIT_NAME:-}" && -n "${LINUX_SETUP_GIT_EMAIL:-}" ]]; then
        touch "$LOCAL_GITCONFIG"
        git config --file "$LOCAL_GITCONFIG" user.name  "$LINUX_SETUP_GIT_NAME"
        git config --file "$LOCAL_GITCONFIG" user.email "$LINUX_SETUP_GIT_EMAIL"
        log_success "Git identity written from environment variables to $LOCAL_GITCONFIG"
        log_info "  name:  $LINUX_SETUP_GIT_NAME"
        log_info "  email: $LINUX_SETUP_GIT_EMAIL"
        return 0
    fi

    if [[ -n "$current_name" && -n "$current_email" ]]; then
        log_info "Current git identity:"
        log_info "  name:  $current_name"
        log_info "  email: $current_email"
        printf '\nPress Enter to keep existing values, or type new ones.\n\n'
    fi

    local name email

    name="$(prompt_with_default "Full name" "$current_name")"
    if [[ -z "$name" ]]; then
        log_warn "Name cannot be empty. Skipping git identity configuration."
        return 0
    fi

    email="$(prompt_with_default "Email address" "$current_email")"
    if [[ -z "$email" ]]; then
        log_warn "Email cannot be empty. Skipping git identity configuration."
        return 0
    fi

    # Validate email format
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        log_warn "Email '$email' does not look valid. Skipping git identity configuration."
        return 0
    fi

    touch "$LOCAL_GITCONFIG"
    git config --file "$LOCAL_GITCONFIG" user.name  "$name"
    git config --file "$LOCAL_GITCONFIG" user.email "$email"

    log_success "Git identity written to $LOCAL_GITCONFIG"
    log_info "  name:  $name"
    log_info "  email: $email"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    # Allow non-interactive seeding via environment variables so CI and
    # automated setups can pre-configure git identity without a TTY.
    if [[ -n "${LINUX_SETUP_GIT_NAME:-}" && -n "${LINUX_SETUP_GIT_EMAIL:-}" ]]; then
        configure_git_identity
        echo_header "Configuration complete"
        log_success "Your machine-local settings are in $LOCAL_GITCONFIG"
        log_info "This file is not committed — it stays on this machine only."
        return 0
    fi

    if ! is_interactive; then
        log_info "Non-interactive environment detected; skipping configure step."
        log_info "Run 'bash configure/configure.sh' manually to set up git identity."
        return 0
    fi

    configure_git_identity

    echo_header "Configuration complete"
    log_success "Your machine-local settings are in $LOCAL_GITCONFIG"
    log_info "This file is not committed — it stays on this machine only."
}

main
