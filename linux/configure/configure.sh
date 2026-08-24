#!/usr/bin/env bash
# Interactive configuration step.
#
# Prompts for anything that cannot have a machine-independent default:
#   - Git identity (name + email) -- written to ~/.gitconfig.local so the
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
PROMPT_TIMEOUT_SECONDS="${DEVSETUP_PROMPT_TIMEOUT_SECONDS:-${LINUX_SETUP_PROMPT_TIMEOUT_SECONDS:-60}}"

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

    # Deliberately loud. A bootstrap sitting silently at a bare "Name:" looks
    # indistinguishable from a hang, so the prompt announces itself, says what
    # it wants, and shows what pressing Enter will do.
    {
        printf '\n%s%s input needed%s\n' "$UI_YELLOW$UI_BOLD" "$UI_ARROW" "$UI_RESET"
        printf '  %s\n' "$prompt"
        if [[ -n "$default" ]]; then
            printf '  %spress Enter to accept:%s %s%s%s\n' \
                "$UI_DIM" "$UI_RESET" "$UI_BOLD" "$default" "$UI_RESET"
        fi
        if [[ "${PROMPT_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] && [[ "$PROMPT_TIMEOUT_SECONDS" -gt 0 ]]; then
            printf '  %stimes out after %ss%s\n' "$UI_DIM" "$PROMPT_TIMEOUT_SECONDS" "$UI_RESET"
        fi
        printf '  %s>%s ' "$UI_CYAN" "$UI_RESET"
    } > "$prompt_out"

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
    # DEVSETUP_* is the documented name on both platforms; the per-platform
    # spelling is kept as a fallback so older notes keep working.
    local DEVSETUP_GIT_NAME="${DEVSETUP_GIT_NAME:-${LINUX_SETUP_GIT_NAME:-}}"
    local DEVSETUP_GIT_EMAIL="${DEVSETUP_GIT_EMAIL:-${LINUX_SETUP_GIT_EMAIL:-}}"

    if [[ -n "${DEVSETUP_GIT_NAME:-}" ]]; then
        current_name="${DEVSETUP_GIT_NAME}"
    fi
    if [[ -n "${DEVSETUP_GIT_EMAIL:-}" ]]; then
        current_email="${DEVSETUP_GIT_EMAIL}"
    fi

    if [[ -n "${DEVSETUP_GIT_NAME:-}" && -n "${DEVSETUP_GIT_EMAIL:-}" ]]; then
        touch "$LOCAL_GITCONFIG"
        git config --file "$LOCAL_GITCONFIG" user.name  "$DEVSETUP_GIT_NAME"
        git config --file "$LOCAL_GITCONFIG" user.email "$DEVSETUP_GIT_EMAIL"
        log_success "Git identity written from environment variables to $LOCAL_GITCONFIG"
        log_info "  name:  $DEVSETUP_GIT_NAME"
        log_info "  email: $DEVSETUP_GIT_EMAIL"
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
    if [[ -n "${DEVSETUP_GIT_NAME:-}" && -n "${DEVSETUP_GIT_EMAIL:-}" ]]; then
        configure_git_identity
        echo_header "Configuration complete"
        log_success "Your machine-local settings are in $LOCAL_GITCONFIG"
        log_info "This file is not committed -- it stays on this machine only."
        return 0
    fi

    # A non-interactive shell can still be fully configured when the identity
    # is supplied by environment, which is the entire point of those variables
    # (CI, cloud-init, an unattended re-image). Only bail when there is both no
    # TTY to prompt on and nothing to work from.
    if ! is_interactive \
        && [[ -z "${DEVSETUP_GIT_NAME:-${LINUX_SETUP_GIT_NAME:-}}" \
           || -z "${DEVSETUP_GIT_EMAIL:-${LINUX_SETUP_GIT_EMAIL:-}}" ]]; then
        log_info "Non-interactive environment and no git identity in the environment."
        log_info "Either run manually:  bash configure/configure.sh"
        log_info "or pre-seed it:       DEVSETUP_GIT_NAME=... DEVSETUP_GIT_EMAIL=... ./run.sh --only configure"
        return 0
    fi

    configure_git_identity

    echo_header "Configuration complete"
    log_success "Your machine-local settings are in $LOCAL_GITCONFIG"
    log_info "This file is not committed -- it stays on this machine only."
}

main
