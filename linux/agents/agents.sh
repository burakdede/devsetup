#!/usr/bin/env bash
# Coding agent setup -- Claude Code, Codex, OpenCode.
#
# What this does:
#   1. Verifies each agent CLI is installed (install instructions printed if not).
#   2. Creates ~/.config/agents/ as the central config hub (symlinked from dotfiles).
#   3. Symlinks each agent's global instructions / config file into the central hub
#      so you manage one place and all three agents pick it up.
#
# Central config layout (in dotfiles directory):
#   ~/.config/agents/
#   ├── instructions.md   -- shared system prompt / coding guidelines
#   └── memory/           -- shared scratch memory (ignored by git via .gitkeep)
#
# Agent-specific locations:
#   Claude Code : ~/.claude/CLAUDE.md          → ~/.config/agents/instructions.md
#   Codex       : ~/.codex/config.toml         (managed by codex itself; model set here)
#   OpenCode    : ~/.config/opencode/config.json (created here if absent)
#
# Skip: LINUX_SETUP_SKIP_AGENTS=1 ./run.sh --only agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../utils/utils.sh"

AGENTS_CONFIG_DIR="$HOME/.config/agents"
CENTRAL_INSTRUCTIONS="$AGENTS_CONFIG_DIR/instructions.md"

# ─── Guard ────────────────────────────────────────────────────────────────────
if should_skip_step AGENTS; then
    log_info "Skipping agents (LINUX_SETUP_SKIP_AGENTS is set)."
    exit 0
fi

echo_header "Coding agents (Claude Code · Codex · OpenCode)"

# ─── Verify agents are installed ──────────────────────────────────────────────
agents_ok=1

if ! command -v claude &>/dev/null; then
    log_warn "claude not found -- install: npm install -g @anthropic-ai/claude-code"
    agents_ok=0
else
    log_success "claude $(claude --version 2>/dev/null | head -1)"
fi

if ! command -v codex &>/dev/null; then
    log_warn "codex not found -- download from https://github.com/openai/codex/releases"
    agents_ok=0
else
    log_success "codex found"
fi

if ! command -v opencode &>/dev/null; then
    log_warn "opencode not found -- install: npm install -g opencode-ai  or visit opencode.ai"
    agents_ok=0
else
    log_success "opencode $(opencode --version 2>/dev/null | head -1)"
fi

# ─── Central config directory ─────────────────────────────────────────────────
# dotfiles.sh symlinks ~/.config/agents/ from the dotfiles/ directory. If for some reason
# it is not yet a symlink (e.g. this step runs before dotfiles), create it.
if [[ ! -e "$AGENTS_CONFIG_DIR" ]]; then
    mkdir -p "$AGENTS_CONFIG_DIR"
    log_info "Created $AGENTS_CONFIG_DIR"
fi
mkdir -p "$AGENTS_CONFIG_DIR/memory"

# ─── Claude Code: global CLAUDE.md ────────────────────────────────────────────
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_DIR"

if [[ ! -f "$CENTRAL_INSTRUCTIONS" ]]; then
    log_warn "Claude Code: $CENTRAL_INSTRUCTIONS not found -- run dotfiles step first, then re-run --only agents."
elif [[ -L "$CLAUDE_MD" ]]; then
    log_info "Claude Code: CLAUDE.md symlink already in place"
elif [[ -f "$CLAUDE_MD" ]]; then
    mv "$CLAUDE_MD" "${CLAUDE_MD}.bak"
    log_info "Claude Code: backed up existing CLAUDE.md to CLAUDE.md.bak"
    ln -s "$CENTRAL_INSTRUCTIONS" "$CLAUDE_MD"
    log_success "Claude Code: CLAUDE.md → $CENTRAL_INSTRUCTIONS"
else
    ln -s "$CENTRAL_INSTRUCTIONS" "$CLAUDE_MD"
    log_success "Claude Code: CLAUDE.md → $CENTRAL_INSTRUCTIONS"
fi

# ─── OpenCode: global config ──────────────────────────────────────────────────
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG="$OPENCODE_DIR/config.json"

mkdir -p "$OPENCODE_DIR"

if [[ ! -f "$OPENCODE_CONFIG" ]]; then
    cat > "$OPENCODE_CONFIG" <<EOF
{
  "autoshare": false,
  "model": "anthropic/claude-sonnet-4-6"
}
EOF
    log_success "OpenCode: created $OPENCODE_CONFIG"
else
    log_info "OpenCode: $OPENCODE_CONFIG already exists -- skipping"
fi

# ─── Codex: config.toml ───────────────────────────────────────────────────────
CODEX_CONFIG="$HOME/.codex/config.toml"
mkdir -p "$HOME/.codex"

if [[ ! -f "$CODEX_CONFIG" ]]; then
    cat > "$CODEX_CONFIG" <<'EOF'
model                  = "o4-mini"
personality            = "pragmatic"
model_reasoning_effort = "medium"
approvals_reviewer     = "user"
EOF
    log_success "Codex: created $CODEX_CONFIG"
else
    log_info "Codex: $CODEX_CONFIG already exists -- skipping"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
log_success "Central agent config: $AGENTS_CONFIG_DIR"
log_success "  Edit $CENTRAL_INSTRUCTIONS to update instructions for all agents."

if [[ "$agents_ok" -eq 0 ]]; then
    log_warn "One or more agents were not found -- install them and re-run: ./run.sh --only agents"
fi
