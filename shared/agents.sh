#!/usr/bin/env bash
# Coding agent configuration hub -- shared by macOS and Ubuntu.
#
# This file contains no OS-specific logic. It is sourced by
# mac/agents/agents.sh and linux/agents/agents.sh, which set the
# AGENT_HINT_* variables to the right install command for their platform and
# then call configure_agents.
#
# ── The idea ──────────────────────────────────────────────────────────────────
# One instructions file drives every agent:
#
#   dotfiles/.config/agents/instructions.md
#     -> ~/.claude/CLAUDE.md              (Claude Code, symlink)
#     -> ~/.codex/AGENTS.md               (Codex, symlink)
#     -> ~/.config/opencode/config.json   (OpenCode, "instructions" key)
#
# Edit that one file and all three agents pick the change up.
#
# ── Why no model is pinned ────────────────────────────────────────────────────
# These configs deliberately do NOT hardcode a model id. Model names change
# often, and a stale id committed to a dotfiles repo silently pins a fresh
# machine to an old model, or names one that no longer exists. Each CLI's own
# default is a better answer; set a model per machine with the tool's own
# `/model` command if you want something specific.

AGENTS_CONFIG_DIR="$HOME/.config/agents"
CENTRAL_INSTRUCTIONS="$AGENTS_CONFIG_DIR/instructions.md"

# Symlink $2 -> $1, backing up an existing regular file first.
link_agent_instructions() {
    local source_file="$1"
    local target="$2"
    local label="$3"

    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        if [[ "$(readlink "$target")" == "$source_file" ]]; then
            log_info "$label: instructions symlink already in place"
            return 0
        fi
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        mv "$target" "${target}.bak"
        log_info "$label: backed up existing $(basename "$target") to $(basename "$target").bak"
    fi

    ln -s "$source_file" "$target"
    log_success "$label: $(basename "$target") -> $source_file"
}

check_agent_installed() {
    local command_name="$1"
    local label="$2"
    local hint="$3"

    if command -v "$command_name" &>/dev/null; then
        log_success "$label $("$command_name" --version 2>/dev/null | head -1)"
        return 0
    fi

    log_warn "$label not found -- install: $hint"
    return 1
}

configure_agents() {
    echo_header "Coding agents (Claude Code · Codex · OpenCode)"

    local agents_ok=1
    check_agent_installed claude   "Claude Code" "${AGENT_HINT_CLAUDE:-see claude.ai/code}"   || agents_ok=0
    check_agent_installed codex    "Codex"       "${AGENT_HINT_CODEX:-see openai.com/codex}"  || agents_ok=0
    check_agent_installed opencode "OpenCode"    "${AGENT_HINT_OPENCODE:-see opencode.ai}"    || agents_ok=0

    # dotfiles.sh symlinks ~/.config/agents from the repo. If that step has not
    # run yet there is nothing to point the agents at.
    if [[ ! -f "$CENTRAL_INSTRUCTIONS" ]]; then
        log_warn "$CENTRAL_INSTRUCTIONS not found."
        log_warn "Run the dotfiles step first, then re-run: ./run.sh --only agents"
        return 0
    fi
    mkdir -p "$AGENTS_CONFIG_DIR/memory"

    # ─── Claude Code ──────────────────────────────────────────────────────────
    # Reads ~/.claude/CLAUDE.md as the global system prompt.
    link_agent_instructions "$CENTRAL_INSTRUCTIONS" "$HOME/.claude/CLAUDE.md" "Claude Code"

    # ─── Codex ────────────────────────────────────────────────────────────────
    # Reads ~/.codex/AGENTS.md as its global instructions. config.toml is left
    # to Codex itself: it holds auth and machine state, and overwriting it
    # would clobber project trust entries.
    link_agent_instructions "$CENTRAL_INSTRUCTIONS" "$HOME/.codex/AGENTS.md" "Codex"

    # ─── OpenCode ─────────────────────────────────────────────────────────────
    # Reads ~/.config/opencode/config.json. The "instructions" key takes a list
    # of files to prepend, which is how the shared file reaches OpenCode.
    local opencode_config="$HOME/.config/opencode/config.json"
    mkdir -p "$(dirname "$opencode_config")"

    if [[ -f "$opencode_config" ]]; then
        if grep -q '"instructions"' "$opencode_config"; then
            log_info "OpenCode: already reading the shared instructions"
        elif command -v jq >/dev/null 2>&1; then
            # Add the one key we care about and leave everything else untouched.
            # Warning about it was not enough: the file predates this step on
            # any machine set up before it existed, so it never got wired.
            local tmp
            tmp="$(mktemp)"
            if jq --arg p "$CENTRAL_INSTRUCTIONS" '.instructions = [$p]' \
                 "$opencode_config" > "$tmp" 2>/dev/null; then
                cp "$opencode_config" "${opencode_config}.bak"
                mv "$tmp" "$opencode_config"
                log_success "OpenCode: added instructions to the existing config (backup: config.json.bak)"
            else
                rm -f "$tmp"
                log_warn "OpenCode: could not parse $opencode_config; add by hand:"
                log_warn "  \"instructions\": [\"$CENTRAL_INSTRUCTIONS\"]"
            fi
        else
            log_warn "OpenCode: jq not available; add by hand:"
            log_warn "  \"instructions\": [\"$CENTRAL_INSTRUCTIONS\"]"
        fi
    else
        cat > "$opencode_config" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "autoshare": false,
  "instructions": ["$CENTRAL_INSTRUCTIONS"]
}
EOF
        log_success "OpenCode: created $opencode_config"
    fi

    echo ""
    log_success "Central agent config: $AGENTS_CONFIG_DIR"
    log_success "  Edit $CENTRAL_INSTRUCTIONS to update instructions for all three agents."

    if [[ "$agents_ok" -eq 0 ]]; then
        log_warn "One or more agents were not found -- install them and re-run: ./run.sh --only agents"
    fi
}
