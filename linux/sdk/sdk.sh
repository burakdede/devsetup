#!/usr/bin/env bash
# SDKMAN installation and package bootstrap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"

load_sdkman() {
    local restore_nounset=0

    if [[ -s "$SDKMAN_INIT" ]]; then
        if [[ -o nounset ]]; then
            restore_nounset=1
            set +u
        fi
        # shellcheck source=/dev/null
        source "$SDKMAN_INIT"
        if [[ "$restore_nounset" -eq 1 ]]; then
            set -u
        fi
        return 0
    fi

    log_info "Installing SDKMAN."
    local tmp_installer
    tmp_installer="$(mktemp)"
    curl -fsSL "https://get.sdkman.io" -o "$tmp_installer"
    if [[ -o nounset ]]; then
        restore_nounset=1
        set +u
    fi
    # Do not let SDKMAN mutate shell rc files; we manage init explicitly in dotfiles.
    SDKMAN_DIR="$HOME/.sdkman" rcupdate=false bash "$tmp_installer"
    if [[ "$restore_nounset" -eq 1 ]]; then
        set -u
        restore_nounset=0
    fi
    rm -f "$tmp_installer"
    if [[ -o nounset ]]; then
        restore_nounset=1
        set +u
    fi
    # shellcheck source=/dev/null
    source "$SDKMAN_INIT"
    if [[ "$restore_nounset" -eq 1 ]]; then
        set -u
    fi
}

run_sdk() {
    local restore_nounset=0
    if [[ -o nounset ]]; then
        restore_nounset=1
        set +u
    fi
    sdk "$@"
    local rc=$?
    if [[ "$restore_nounset" -eq 1 ]]; then
        set -u
    fi
    return "$rc"
}

install_sdk_packages() {
    echo_header "SDKMAN packages"

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_warn "Missing ${PACKAGES_FILE}; skipping SDKMAN packages."
        return 0
    fi

    local candidate
    while IFS= read -r candidate || [[ -n "$candidate" ]]; do
        candidate="${candidate%%#*}"
        candidate="$(trim "$candidate")"
        [[ -z "$candidate" ]] && continue

        log_info "Installing SDKMAN candidate: $candidate"
        run_sdk install "$candidate" || log_warn "Unable to install ${candidate}. Review available versions with 'sdk list ${candidate}'."
    done < "$PACKAGES_FILE"
}

main() {
    load_sdkman
    run_sdk selfupdate || true
    run_sdk update || true
    install_sdk_packages

    echo_header "SDKMAN setup complete"
    log_success "SDKMAN is initialized for future shells via ~/.sdkman/bin/sdkman-init.sh."
}

main
