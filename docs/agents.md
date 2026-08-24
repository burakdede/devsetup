# Coding agents

[← back to README](../README.md)

## Coding agents

`dotfiles/.config/agents/instructions.md` is the shared system prompt, and all
three agents are wired to that one file:

| Agent | How it reads the shared instructions |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` symlinked to it |
| Codex | `~/.codex/AGENTS.md` symlinked to it |
| OpenCode | `~/.config/opencode/config.json` lists it under `instructions` |

Edit `dotfiles/.config/agents/instructions.md` and all three pick the change up.

The step is non-destructive: an existing `~/.codex/config.toml` is left alone
because it holds auth and project trust state, and an existing OpenCode
`config.json` is kept as-is with a warning if it is not reading the shared
file.

**No model id is pinned.** Model names change often, and a stale id committed
to a dotfiles repo silently pins a fresh machine to an old model or names one
that no longer exists. Each CLI's own default is used; set a model per machine
with the tool's own `/model` command. (The previous template pinned Codex to
`o4-mini`, which was long dead.)

The logic is OS-neutral and lives in `shared/agents.sh`; `mac/agents/agents.sh`
and `linux/agents/agents.sh` are thin wrappers that only supply the per-OS
install hint.
