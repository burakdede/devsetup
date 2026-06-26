#!/usr/bin/env bash
# Post-install verification summary.
#
# Prints a ✓/✗ table of every expected command and configuration artefact.
# Designed to be run after `./run.sh` completes on a fresh machine.
#
# Usage:
#   bash scripts/verify-install.sh
#   ./run.sh --verify      (alias; see run.sh)

set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.cargo/bin:$PATH"

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
RESET=$'\033[0m'

PASS=0
FAIL=0
WARN=0

ok()   { printf '  %s✓%s  %s\n'      "$GREEN"  "$RESET" "$1"; PASS=$((PASS+1)); }
fail() { printf '  %s✗%s  %s\n'      "$RED"    "$RESET" "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  %s~%s  %s\n'      "$YELLOW" "$RESET" "$1"; WARN=$((WARN+1)); }

section() { printf '\n%s── %s%s\n' "$CYAN" "$1" "$RESET"; }

check_cmd() {
    local label="${2:-$1}"
    if command -v "$1" >/dev/null 2>&1; then
        local ver
        ver="$(command "$1" --version 2>/dev/null | head -n1 || true)"
        ok "$label${ver:+  ($ver)}"
    else
        fail "$label  (not found)"
    fi
}

check_cmd_optional() {
    local label="${2:-$1}"
    if command -v "$1" >/dev/null 2>&1; then
        local ver
        ver="$(command "$1" --version 2>/dev/null | head -n1 || true)"
        ok "$label${ver:+  ($ver)}"
    else
        warn "$label  (not found — optional)"
    fi
}

check_file() {
    local path="$1"
    local label="${2:-$path}"
    if [[ -e "$path" ]]; then
        ok "$label"
    else
        fail "$label  (missing: $path)"
    fi
}

check_symlink() {
    local path="$1"
    local label="${2:-$path}"
    if [[ -L "$path" ]]; then
        ok "$label  → $(readlink -f "$path" 2>/dev/null || readlink "$path")"
    elif [[ -e "$path" ]]; then
        warn "$label  (exists but is not a symlink)"
    else
        fail "$label  (missing: $path)"
    fi
}

check_default_shell() {
    local current
    current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
    if [[ "$current" == *"zsh"* ]]; then
        ok "Default shell: $current"
    else
        warn "Default shell is $current (expected zsh)"
    fi
}

check_alternative() {
    local name="$1"
    local expected="$2"
    local current
    current="$(update-alternatives --query "$name" 2>/dev/null \
        | awk '/^Value:/ {print $2}' | head -n1 || true)"
    if [[ "$current" == "$expected" ]]; then
        ok "update-alternatives $name → $current"
    elif [[ -n "$current" ]]; then
        warn "update-alternatives $name → $current (expected $expected)"
    else
        warn "update-alternatives $name not configured"
    fi
}

version_ge() {
    # returns 0 if $1 >= $2
    local current="$1"
    local required="$2"
    [[ "$(printf '%s\n' "$required" "$current" | sort -V | head -n1)" == "$required" ]]
}

check_nvim_min_version() {
    local required="$1"
    if ! command -v nvim >/dev/null 2>&1; then
        fail "Neovim not found (required >= $required)"
        return 0
    fi

    local current
    current="$(nvim --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')"
    if version_ge "$current" "$required"; then
        ok "Neovim version $current (required >= $required)"
    else
        fail "Neovim version $current is too old (required >= $required)"
    fi
}

check_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if [[ ! -f "$file" ]]; then
        fail "$label  (missing file: $file)"
        return 0
    fi

    if grep -Eq "$pattern" "$file"; then
        ok "$label"
    else
        fail "$label  (pattern not found)"
    fi
}

# ── Report ────────────────────────────────────────────────────────────────────

printf '\n%s══ Post-install verification ══%s\n' "$CYAN" "$RESET"

section "Core CLI tools"
check_cmd rg       "ripgrep"
check_cmd fd       "fd"
check_cmd bat      "bat"
check_cmd jq       "jq"
check_cmd yq       "yq"
check_cmd eza      "eza"
check_cmd sd       "sd"
check_cmd scc      "scc"
check_cmd_optional hcloud "hcloud (IaC)"
check_cmd fzf      "fzf"
check_cmd tree     "tree"
check_cmd gh       "GitHub CLI"

section "Runtime managers"
check_cmd mise     "mise"
check_cmd uv       "uv"
check_cmd rustup   "rustup"

section "Language runtimes"
check_cmd node     "Node.js"
check_cmd go       "Go"
check_cmd python3  "Python"
check_cmd rustc    "Rust"
check_cmd java     "Java"

section "Developer tooling"
check_cmd docker        "Docker"
check_cmd pre-commit    "pre-commit"
check_cmd ruff          "ruff"
check_cmd yamllint      "yamllint"
check_cmd eslint        "ESLint"
check_cmd prettier      "Prettier"
check_cmd shellcheck    "ShellCheck"
check_cmd just          "just (task runner)"
check_cmd direnv        "direnv"
check_cmd shfmt         "shfmt"
check_cmd_optional terraform      "Terraform (IaC)"
check_cmd_optional tflint         "TFLint (IaC)"
check_cmd_optional terragrunt     "Terragrunt (IaC)"
check_cmd_optional terraform-docs "terraform-docs (IaC)"
check_cmd claude        "Claude Code"
check_cmd_optional codex     "Codex"
check_cmd_optional opencode  "OpenCode"

section "Terminal"
check_cmd_optional wezterm "WezTerm"

section "Shell"
check_cmd zsh      "zsh"
check_default_shell

section "Editor"
check_cmd nvim "Neovim"
check_nvim_min_version "0.11.0"
if command -v update-alternatives >/dev/null 2>&1; then
    check_alternative vim    "$(command -v nvim 2>/dev/null || true)"
    check_alternative editor "$(command -v nvim 2>/dev/null || true)"
fi

section "Multiplexer"
check_cmd tmux "tmux"

section "Dotfiles (symlinks)"
check_symlink "$HOME/.zshrc"                ".zshrc"
check_symlink "$HOME/.zshenv"               ".zshenv"
check_symlink "$HOME/.zprofile"             ".zprofile"
check_symlink "$HOME/.zsh_plugins.txt"      ".zsh_plugins.txt"
check_symlink "$HOME/.p10k.zsh"             ".p10k.zsh"
check_symlink "$HOME/.gitconfig"            ".gitconfig"
check_symlink "$HOME/.bash_aliases"         ".bash_aliases"
check_symlink "$HOME/.config/nvim"          ".config/nvim"
check_symlink "$HOME/.config/wezterm"       ".config/wezterm"
check_symlink "$HOME/.config/tmux"          ".config/tmux"

section "Neovim config"
check_file "$HOME/.config/nvim/init.lua"                         "init.lua"
check_file "$HOME/.config/nvim/lua/plugins/lsp.lua"              "lua/plugins/lsp.lua"

section "Terminal stack compatibility"
check_contains "$HOME/.config/wezterm/wezterm.lua" 'config\.term\s*=\s*"xterm-256color"' "WezTerm uses xterm-256color term"
check_contains "$HOME/.config/tmux/tmux.conf" 'default-terminal "tmux-256color"' "tmux default-terminal is tmux-256color"
check_contains "$HOME/.config/tmux/tmux.conf" 'terminal-overrides.*,wezterm:RGB' "tmux enables RGB for wezterm"
check_contains "$HOME/.config/tmux/tmux.conf" "christoomey/vim-tmux-navigator" "tmux navigator plugin declared"
check_contains "$HOME/.config/nvim/lua/plugins/tools.lua" "vim-tmux-navigator" "nvim tmux-navigator plugin declared"
check_contains "$HOME/.zshrc" "powerlevel10k" "zsh loads powerlevel10k"

if command -v infocmp >/dev/null 2>&1; then
    if infocmp tmux-256color >/dev/null 2>&1; then
        ok "terminfo has tmux-256color"
    else
        warn "terminfo missing tmux-256color (colors may degrade inside tmux)"
    fi
else
    warn "infocmp not available; skipped terminfo check"
fi

if [[ -f "$HOME/.zsh_plugins.zsh" ]] && grep -Eq '^[[:space:]]*warning:' "$HOME/.zsh_plugins.zsh"; then
    fail "$HOME/.zsh_plugins.zsh contains warning lines (regenerate antidote bundle)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

printf '\n%s══ Summary ══%s\n' "$CYAN" "$RESET"
printf '  %s✓ %d passed%s\n' "$GREEN"  "$PASS" "$RESET"
if [[ $WARN -gt 0 ]]; then
    printf '  %s~ %d warnings%s\n' "$YELLOW" "$WARN" "$RESET"
fi
if [[ $FAIL -gt 0 ]]; then
    printf '  %s✗ %d failed%s\n' "$RED" "$FAIL" "$RESET"
    printf '\nSome checks failed. Re-run the relevant steps or check the README.\n'
    exit 1
fi

printf '\nAll checks passed.\n'
