# Customization

## Philosophy

This repository is usable as-is, but it is also meant to be easy to adapt. Customization should mostly happen in manifests, version pins, and optional modules rather than by rewriting orchestration logic.

## Skip Flags

Any major install step can be skipped with `LINUX_SETUP_SKIP_<STEP>=1`.

Example:

```bash
LINUX_SETUP_SKIP_DOCKER=1 LINUX_SETUP_SKIP_CHROME=1 ./run.sh
```

Available skip flags:

| Variable | Skips |
|---|---|
| `LINUX_SETUP_SKIP_DOCKER` | Docker CLI and Compose plugin |
| `LINUX_SETUP_SKIP_SNAPS` | All snap packages |
| `LINUX_SETUP_SKIP_CHROME` | Google Chrome |
| `LINUX_SETUP_SKIP_GITHUB_RELEASE_TOOLS` | GitHub-release binaries such as `yq`, `eza`, `sd`, `scc` |
| `LINUX_SETUP_SKIP_UV` | `uv` and `uv`-managed tools |
| `LINUX_SETUP_SKIP_CLAUDE` | Claude Code |
| `LINUX_SETUP_SKIP_NPM_TOOLS` | npm CLIs and MCP packages |
| `LINUX_SETUP_SKIP_GO` | Go toolchain via `mise` |
| `LINUX_SETUP_SKIP_PYTHON` | Python toolchain via `mise` |
| `LINUX_SETUP_SKIP_RUST` | Rust toolchain via `rustup` |
| `LINUX_SETUP_SKIP_IAC_TOOLS` | IaC tooling via `mise` (`terraform`, `tflint`, `terragrunt`, `terraform-docs`) |
| `LINUX_SETUP_SKIP_UFW` | firewall setup |
| `LINUX_SETUP_SKIP_WEZTERM` | terminal installation in verification and smoke flows |
| `LINUX_SETUP_SKIP_NEOVIM` | editor installation in verification and smoke flows |
| `LINUX_SETUP_SKIP_FONTS` | Nerd Fonts installation |

## Optional Modules

These run by default, but you can skip them when needed:

- `git`: GitHub SSH setup (`--skip-git`)
- `settings`: GNOME desktop preferences (`--skip-settings`)

They are interactive/workstation-specific, so skip flags are provided for unattended runs.

## HiDPI Display Tuning (GNOME)

The settings step now applies HiDPI-friendly defaults:

- enables fractional scaling support
- sets text scale to `1.15`
- sets cursor size to `32`
- sets font rendering defaults: `rgba` antialiasing, `slight` hinting, `rgb` subpixel order
- sets GNOME monospace font to `JetBrainsMono Nerd Font 12`

Override during settings run:

```bash
LINUX_SETUP_TEXT_SCALE=1.20 LINUX_SETUP_CURSOR_SIZE=36 ./run.sh
```

Panel-specific font tuning:

```bash
LINUX_SETUP_FONT_RGBA_ORDER=rgb \
LINUX_SETUP_FONT_ANTIALIASING=rgba \
LINUX_SETUP_FONT_HINTING=slight \
LINUX_SETUP_MONOSPACE_FONT="JetBrainsMono Nerd Font 12" \
./run.sh --include-settings
./run.sh
```

Notes:

- Use `LINUX_SETUP_FONT_RGBA_ORDER=bgr` only if your panel subpixel layout is BGR.
- On high-DPI screens, `slight` hinting is usually cleaner than `full`.

## Wallpapers (Desktop + Login Screen)

The settings step can configure both:

- Desktop wallpaper (`org.gnome.desktop.background`)
- Login screen wallpaper (GDM dconf profile)

Default image locations (relative to repo root):

- `assets/wallpapers/desktop.jpg`
- `assets/wallpapers/login.jpg`

Override with environment variables:

```bash
LINUX_SETUP_DESKTOP_WALLPAPER_PATH=/absolute/path/my-desktop.jpg \
LINUX_SETUP_LOGIN_WALLPAPER_PATH=/absolute/path/my-login.jpg \
./run.sh --include-settings
```

Notes:

- Relative paths are resolved from the repository root.
- Login wallpaper setup writes system files under `/etc/dconf` and `/usr/share/backgrounds`, so it requires `sudo`.
- If either image is missing, setup logs a warning and continues.

## Manifests

Most package decisions live in text manifests:

- `system/apt-packages.txt`
- `system/snap-packages.txt`
- `system/github-tools.txt`
- `system/npm-packages.txt`
- `system/uv-tools.txt`
- `sdk/packages.txt`

If you want to tailor the machine, start there first.

## Version Pins

Pinned versions live in [`versions.txt`](../versions.txt).

This is the right place to update:

- `mise`
- Node
- Go
- Python
- Rust
- Terraform
- TFLint
- Terragrunt
- terraform-docs
- Neovim
- WezTerm
- Nerd Fonts

Upgrade flow:

1. Change the version in `versions.txt`.
2. Rerun the relevant step or `./run.sh`.
3. Verify with `./run.sh --verify` and `bash scripts/test.sh`.
4. Commit only after the new pin is stable.

## Dotfiles And Personal Preferences

The repo includes personal dotfiles, but they are installed through a dedicated step so they are easy to replace or fork.

Practical ways to adapt the repo:

- swap the contents of `dotfiles/` with your own
- keep `system/` mostly generic and move personal preferences into `dotfiles/`, `git/`, and `utils/settings.sh`
- leave `run.sh` orchestration alone unless the execution order itself needs to change

## Zsh Profile Selection

The shell step supports two fast profiles:

- `antidote-p10k` (default)
- `zsh4humans`

Choose profile during bootstrap:

```bash
LINUX_SETUP_ZSH_PROFILE=antidote-p10k ./run.sh --only shell
LINUX_SETUP_ZSH_PROFILE=zsh4humans ./run.sh --only shell
```

Profile can also be overridden at runtime in `~/.zshrc` via `ZSH_PROFILE`.

## WezTerm + tmux + Neovim Integration

The default dotfiles now align these tools for a consistent workflow:

- WezTerm starts your login shell (`$SHELL`, fallback `/bin/zsh`)
- zsh can auto-attach to tmux session `main` when enabled
- tmux uses zsh login shell and preserves working directory on splits
- Neovim and tmux share pane navigation via `Ctrl-h/j/k/l`

Useful toggles:

```bash
# Enable tmux auto-attach for this machine
echo 'export ZSH_TMUX_AUTO_ATTACH=1' >> ~/.zshrc.local
```

## Upgrade Behavior

Some installs are intentionally skipped if already present. To force reinstall or refresh during a maintenance pass:

```bash
LINUX_SETUP_UPGRADE=1 ./run.sh --only system
```

Use this deliberately. The default behavior favors stability over constant upgrades.
