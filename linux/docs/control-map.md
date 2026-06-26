# Control Map

This document explains who controls what in the terminal stack and where each configuration lives:

- in the repository (source of truth)
- after installation in your home directory

## Ownership Model

`run.sh` orchestrates steps, but each step owns a specific area:

- `system/` owns package/runtime installation
- `dotfiles/` owns user configuration files
- `shell/` owns zsh installation, default shell, and zsh profile backend bootstrap
- `multiplexer/` owns tmux bootstrap (TPM install)
- `terminal/` owns WezTerm package install/default terminal setup
- `editor/` owns Neovim binary install/alternatives

## Terminal Stack Control

| Aspect | Primary owner | In-repo config | Installed location |
|---|---|---|---|
| WezTerm behavior | `dotfiles` | `dotfiles/.config/wezterm/wezterm.lua` | `~/.config/wezterm/wezterm.lua` |
| tmux behavior | `dotfiles` | `dotfiles/.config/tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| tmux plugin manager bootstrap | `multiplexer` | `multiplexer/multiplexer.sh` | `~/.tmux/plugins/tpm` |
| zsh interactive behavior | `dotfiles` | `dotfiles/.zshrc` | `~/.zshrc` |
| zsh environment defaults | `dotfiles` | `dotfiles/.zshenv` | `~/.zshenv` |
| zsh login shell defaults | `dotfiles` | `dotfiles/.zprofile` | `~/.zprofile` |
| zsh profile backend install | `shell` | `shell/shell.sh` | `~/.local/share/antidote`, `~/.local/share/powerlevel10k`, `~/.local/share/zsh4humans` |
| zsh plugin list (antidote profile) | `dotfiles` | `dotfiles/.zsh_plugins.txt` | `~/.zsh_plugins.txt` |
| p10k prompt config (antidote profile) | `dotfiles` | `dotfiles/.p10k.zsh` | `~/.p10k.zsh` |
| Neovim entrypoint | `dotfiles` | `dotfiles/.config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| Neovim plugins/options | `dotfiles` | `dotfiles/.config/nvim/lua/**` | `~/.config/nvim/lua/**` |
| Neovim binary install | `editor` | `editor/editor.sh` | `/usr/local/bin/nvim` |

## Profile Switching

zsh supports two profiles:

- `antidote-p10k` (default)
- `zsh4humans`

Set during shell step:

```bash
LINUX_SETUP_ZSH_PROFILE=antidote-p10k ./run.sh --only shell
LINUX_SETUP_ZSH_PROFILE=zsh4humans ./run.sh --only shell
```

Runtime override:

- `ZSH_PROFILE` in `~/.zshrc` or `~/.zshrc.local`

## What To Edit For Common Changes

- Prompt look and segments:
  - edit `dotfiles/.p10k.zsh`
- Antidote plugins:
  - edit `dotfiles/.zsh_plugins.txt`
- zsh shell behavior, aliases, completion, optional tmux auto-attach:
  - edit `dotfiles/.zshrc`
- tmux keybindings/splits/theme/plugins:
  - edit `dotfiles/.config/tmux/tmux.conf`
- WezTerm shell/font/window behavior:
  - edit `dotfiles/.config/wezterm/wezterm.lua`
- Neovim keymaps/plugins/LSP:
  - edit files under `dotfiles/.config/nvim/lua/`

## Post-Install Verification Targets

Use these paths to verify symlinked config and runtime assets:

- `~/.zshrc`
- `~/.zshenv`
- `~/.zprofile`
- `~/.zsh_plugins.txt`
- `~/.p10k.zsh`
- `~/.config/wezterm/wezterm.lua`
- `~/.config/tmux/tmux.conf`
- `~/.config/nvim/init.lua`
- `~/.tmux/plugins/tpm`

You can also run:

```bash
./run.sh --verify
```
