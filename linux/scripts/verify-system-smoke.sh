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

# Keep in step with what the system step installs. tree-sitter and delta come
# from linux/system/github-tools.txt; tree-sitter in particular is a hard
# requirement of nvim-treesitter's main branch, which silently falls back to
# regex syntax without it.
base_commands=(
    rg
    fd
    bat
    jq
    yq
    eza
    delta
    tree-sitter
    gitleaks
    actionlint
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
    playwright
    watchexec
    specify
    just
    direnv
    shfmt
    zsh
    tmux
)

for cmd in "${base_commands[@]}"; do
    require_command "$cmd"
done

if ! flag_enabled "${MACHINIST_SKIP_DOCKER:-0}"; then
    require_command docker
fi

if ! flag_enabled "${MACHINIST_SKIP_NEOVIM:-0}"; then
    require_command nvim
fi

if ! flag_enabled "${MACHINIST_SKIP_WEZTERM:-0}"; then
    require_command wezterm
fi

echo "Smoke verification passed"
