#!/usr/bin/env bash
# Post-install verification -- shared by macOS and Ubuntu.
#
# Sourced by mac/scripts/verify-install.sh and linux/scripts/verify-install.sh,
# which add their own OS-specific sections and then call verify_summary.
#
# Wherever possible the checks are DERIVED from the shared manifests rather
# than hand-listed, so a tool added to packages/ is verified automatically and
# the verifier cannot drift from what the installer installs.

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m';  RESET=$'\033[0m'

PASS=0; FAIL=0; WARN=0

ok()   { printf '  %s✓%s  %s\n' "$GREEN"  "$RESET" "$1"; PASS=$((PASS+1)); }
fail() { printf '  %s✗%s  %s\n' "$RED"    "$RESET" "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  %s~%s  %s\n' "$YELLOW" "$RESET" "$1"; WARN=$((WARN+1)); }
section() { printf '\n%s── %s%s\n' "$CYAN" "$1" "$RESET"; }

_version_of() { command "$1" --version 2>/dev/null | head -n1 || true; }

# Display a path home-relative, so labels read "~/.zshrc" not the full path.
_pretty_path() {
    local tilde='~'
    printf '%s' "${1/#$HOME/$tilde}"
}

# Follow a symlink chain to its final target. A dotfile may be reached through
# an intermediate link (~/.claude/CLAUDE.md -> ~/.config/agents/instructions.md
# -> the repo), so comparing only the first hop gives a false negative.
_resolve_link() {
    local path="$1" hops=0 target dir

    while [[ -L "$path" && "$hops" -lt 10 ]]; do
        target="$(readlink "$path")"
        [[ "$target" != /* ]] && target="$(dirname "$path")/$target"
        path="$target"
        hops=$((hops + 1))
    done

    # The file itself may not be a link while a PARENT directory is -- e.g.
    # ~/.config/agents is the symlink and instructions.md inside it is not.
    # `cd -P` resolves symlinks in the directory path. Avoids needing GNU
    # realpath, which macOS does not ship.
    dir="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd)" || dir="$(dirname "$path")"
    printf '%s/%s' "$dir" "$(basename "$path")"
}

check_cmd() {
    local cmd="$1" label="${2:-$1}" ver
    if command -v "$cmd" >/dev/null 2>&1; then
        ver="$(_version_of "$cmd")"
        ok "$label${ver:+  ($ver)}"
    else
        fail "$label  (not found)"
    fi
}

check_cmd_optional() {
    local cmd="$1" label="${2:-$1}" ver
    if command -v "$cmd" >/dev/null 2>&1; then
        ver="$(_version_of "$cmd")"
        ok "$label${ver:+  ($ver)}"
    else
        warn "$label  (not found -- optional)"
    fi
}

check_file() {
    local path="$1"
    local label="${2:-$(_pretty_path "$path")}"
    if [[ -e "$path" ]]; then ok "$label"; else fail "$label  (missing: $path)"; fi
}

check_dir() {
    local path="$1"
    local label="${2:-$(_pretty_path "$path")}"
    if [[ -d "$path" ]]; then ok "$label"; else fail "$label  (missing: $path)"; fi
}

# A dotfile must be a symlink INTO this repo. A regular file there means the
# dotfiles step never ran, or something replaced the link -- edits to it would
# silently not be tracked, which is worth flagging distinctly.
check_symlink() {
    local path="$1"
    local label="${2:-$(_pretty_path "$path")}"
    local target
    if [[ -L "$path" ]]; then
        target="$(_resolve_link "$path")"
        if [[ "$target" == "$REPO_ROOT"* ]]; then
            ok "$label"
        else
            warn "$label  (symlink, but points outside the repo: $target)"
        fi
    elif [[ -e "$path" ]]; then
        fail "$label  (a real file, not a symlink -- re-run the dotfiles step)"
    else
        fail "$label  (missing -- run the dotfiles step)"
    fi
}

check_contains() {
    local path="$1"
    local needle="$2"
    local label="${3:-$needle in $(basename "$path")}"
    if [[ -f "$path" ]] && grep -q -- "$needle" "$path"; then
        ok "$label"
    else
        fail "$label  (not found in $path)"
    fi
}

verify_shared() {
    section "Core CLI"
    local c
    for c in git curl jq rg fd bat eza fzf gh tmux; do check_cmd "$c"; done

    section "Runtime managers"
    check_cmd mise
    check_cmd uv
    check_cmd_optional rustup
    check_cmd_optional cargo

    # ── Tools pinned in the shared mise config ────────────────────────────────
    section "mise tools (dotfiles/.config/mise/config.toml)"
    local mise_cfg="$HOME/.config/mise/config.toml"
    if [[ ! -f "$mise_cfg" ]]; then
        fail "mise config  (missing: $mise_cfg -- run the dotfiles step)"
    elif ! command -v mise >/dev/null 2>&1; then
        fail "mise tools  (mise not installed)"
    else
        local tool
        while IFS= read -r tool; do
            [[ -z "$tool" ]] && continue
            if mise which "$tool" >/dev/null 2>&1; then
                ok "$tool  ($(mise current "$tool" 2>/dev/null || echo installed))"
            else
                fail "$tool  (pinned in mise config but not installed -- run: mise install)"
            fi
        done < <(sed -n '/^\[tools\]/,$p' "$mise_cfg" \
                 | grep -E '^[a-z][a-z0-9-]*[[:space:]]*=' \
                 | sed -E 's/^([a-z0-9-]+).*/\1/')
    fi

    # ── Tools from the shared manifests ──────────────────────────────────────
    section "Shared manifests (packages/)"
    local uv_tools="$REPO_ROOT/packages/uv-tools.txt"
    local npm_tools="$REPO_ROOT/packages/npm-packages.txt"
    local sdkman_list="$REPO_ROOT/packages/sdkman.txt"

    if [[ -f "$uv_tools" ]]; then
        while IFS= read -r c; do check_cmd "$c" "$c  (uv)"; done < <(read_list_file "$uv_tools")
    else
        fail "packages/uv-tools.txt  (missing)"
    fi

    if [[ -f "$npm_tools" ]]; then
        while IFS= read -r c; do check_cmd "$c" "$c  (npm)"; done < <(read_list_file "$npm_tools")
    else
        fail "packages/npm-packages.txt  (missing)"
    fi

    section "SDKMAN"
    if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        ok "sdkman installed"
        local candidate
        while IFS= read -r candidate; do
            if [[ -d "$HOME/.sdkman/candidates/$candidate/current" ]]; then
                ok "$candidate"
            else
                warn "$candidate  (not installed -- run: ./run.sh --only sdk)"
            fi
        done < <(read_list_file "$sdkman_list")
    else
        warn "sdkman  (not installed -- run: ./run.sh --only sdk)"
    fi

    section "Editor"
    check_cmd nvim
    check_file "$HOME/.config/nvim/init.lua" "nvim init.lua"

    section "Agents"
    check_cmd_optional claude   "Claude Code"
    check_cmd_optional codex    "Codex"
    check_cmd_optional opencode "OpenCode"
    check_file "$HOME/.config/agents/instructions.md" "shared agent instructions"
    check_symlink "$HOME/.claude/CLAUDE.md" "Claude Code -> shared instructions"
    check_symlink "$HOME/.codex/AGENTS.md"  "Codex -> shared instructions"

    section "Dotfile symlinks"
    local f
    for f in .zshrc .zshenv .zprofile .zsh_plugins.txt .p10k.zsh .gitconfig .gitignore_global; do
        check_symlink "$HOME/$f"
    done
    for f in nvim tmux wezterm mise agents; do
        check_symlink "$HOME/.config/$f"
    done

    section "Shell configuration"
    check_dir "$HOME/.local/share/antidote"       "antidote"
    check_dir "$HOME/.local/share/powerlevel10k"  "powerlevel10k"
    check_contains "$HOME/.zshenv"  "typeset -U path" "PATH de-duplication enabled"
    check_contains "$HOME/.config/tmux/tmux.conf" "set-clipboard on" "tmux system clipboard"
    check_file "$HOME/.gitconfig.local"
}

verify_summary() {
    printf '\n%s──────────────────────────────────────────%s\n' "$CYAN" "$RESET"
    printf '  %s%d passed%s   %s%d failed%s   %s%d warnings%s\n\n' \
        "$GREEN" "$PASS" "$RESET" "$RED" "$FAIL" "$RESET" "$YELLOW" "$WARN" "$RESET"
    [[ "$FAIL" -eq 0 ]]
}
