#!/usr/bin/env bash

set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

flag_enabled() {
    local value="${1:-0}"
    case "$value" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

echo "==> Verifying smoke-install commands"

base_commands=(
    rg
    fd
    bat
    jq
    yq
    eza
    uv
    mise
    claude
    codex
    opencode
    pre-commit
    ruff
    yamllint
    eslint
    prettier
    just
    direnv
    shfmt
    zsh
    tmux
)

for cmd in "${base_commands[@]}"; do
    require_command "$cmd"
done

if ! flag_enabled "${LINUX_SETUP_SKIP_DOCKER:-0}"; then
    require_command docker
fi

if ! flag_enabled "${LINUX_SETUP_SKIP_NEOVIM:-0}"; then
    require_command nvim
fi

if ! flag_enabled "${LINUX_SETUP_SKIP_WEZTERM:-0}"; then
    require_command wezterm
fi

echo "Smoke verification passed"
