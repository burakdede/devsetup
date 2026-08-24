# devsetup

Developer machine setup for macOS and Ubuntu. One clone, two platforms, shared configs.

## Layout

```
devsetup/
├── dotfiles/          shared cross-platform configs (zsh, nvim, tmux, wezterm, …)
├── packages/          shared tool manifests (SDKMAN, uv, npm)
├── mac/               macOS setup scripts (Homebrew-based)
└── linux/             Ubuntu setup scripts (APT/snap/GitHub-release-based)
```

`dotfiles/` is a plain directory -- no submodule. Edit a file, commit, push. Both machines pull the same change with `git pull`.

### The organising rule

macOS and Ubuntu are different operating systems with different desktop
environments, and this repo does not pretend otherwise. What it does guarantee
is that **anything shared is defined in exactly one place**, and anything
OS-specific lives in that OS's directory.

| Scope | Lives in | Examples |
|---|---|---|
| Shared config | `dotfiles/` | zsh, nvim, tmux, wezterm, git, mise |
| Shared tool lists | `packages/` | SDKMAN candidates, uv tools, npm CLIs |
| OS-specific packages | `mac/`, `linux/` | Brewfile casks, APT, snap, GitHub-release binaries |
| OS-specific behaviour | `mac/`, `linux/` | `defaults write`, GNOME settings, `chsh` vs `usermod` |

So the JVM candidates you get are identical on both machines because they come
from one file, while the window manager and the clipboard daemon are
necessarily different. If you add a cross-platform CLI tool to an OS-specific
list, that is how the two machines drift apart.

---

## Quick start

### macOS

```bash
git clone git@github.com:burakdede/devsetup.git ~/Projects/devsetup
cd ~/Projects/devsetup/mac
./run.sh
```

### Ubuntu

```bash
git clone git@github.com:burakdede/devsetup.git ~/Projects/devsetup
cd ~/Projects/devsetup/linux
./run.sh
```

Both scripts are interactive on first run. Use `--skip-git` to skip the SSH key setup (useful for headless/CI runs).

---

## What gets installed

### macOS (`mac/`)

| Step | What it does |
|---|---|
| `system` | Homebrew + all packages in `Brewfile`, mise runtime manager |
| `dotfiles` | Symlinks `dotfiles/` and `mac/configs/` into `$HOME` |
| `configure` | Prompts for git name/email → writes `~/.gitconfig.local` |
| `shell` | Sets Homebrew zsh as default shell, installs antidote + powerlevel10k |
| `editor` | Neovim via Homebrew, `vi`/`vim` shims, lazy.nvim plugin bootstrap |
| `multiplexer` | Tmux config wiring + TPM (Tmux Plugin Manager) |
| `terminal` | WezTerm via Homebrew Cask |
| `sdk` | SDKMAN -- Java, Kotlin |
| `agents` | Claude Code, Codex, OpenCode -- install checks + central config symlinks |
| `git` | GitHub SSH key generation and connection test |
| `macos` | macOS system defaults via `defaults write` |

Run a single step: `./run.sh --only editor`  
Skip a step: `MACSETUP_SKIP_SDK=1 ./run.sh`  
Re-install: `MACSETUP_UPGRADE=1 ./run.sh --only neovim`

### Linux (`linux/`)

| Step | What it does |
|---|---|
| `system` | APT packages, snap packages, GitHub-release binaries, mise, Nerd Fonts |
| `dotfiles` | Symlinks `dotfiles/` into `$HOME` |
| `configure` | Prompts for git name/email → writes `~/.gitconfig.local` |
| `shell` | Installs zsh, sets it as default shell |
| `editor` | Neovim from GitHub releases, `vi`/`vim`/`editor` alternatives |
| `multiplexer` | Tmux config wiring + TPM |
| `terminal` | WezTerm from GitHub releases, sets as default terminal |
| `sdk` | SDKMAN -- Java, Kotlin |
| `agents` | Claude Code, Codex, OpenCode -- install checks + central config symlinks |
| `git` | GitHub SSH key generation and connection test |
| `settings` | GNOME desktop settings (font, scaling, cursor) |

Run a single step: `./run.sh --only editor`  
Skip a step: `LINUX_SETUP_SKIP_SDK=1 ./run.sh`  
Re-install: `LINUX_SETUP_UPGRADE=1 ./run.sh --only editor`

---

## Shared dotfiles

Everything in `dotfiles/` is cross-platform. OS-specific paths are handled inside each config file at runtime:

- **`.zshenv`** -- XDG dirs, `$EDITOR`, and user PATH entries; sourced by every zsh process
- **`.zprofile`** -- Homebrew init on macOS, mise shims; sourced by login shells only
- **`.zshrc`** -- fzf key-bindings source differs by OS (detected at runtime)
- **`wezterm.lua`** -- uses `wezterm.target_triple:find("darwin")` to switch modifier keys
- **`tmux.conf`** -- fully cross-platform
- **`nvim/`** -- fully cross-platform

### Shell environment: what this setup decides for you

Two deliberate choices in the zsh files that are easy to get wrong:

**Homebrew is initialised in `.zprofile`, not `.zshenv`.** zsh sources files in the
order `/etc/zshenv` → `~/.zshenv` → `/etc/zprofile` → `~/.zprofile` → `~/.zshrc`.
macOS ships an `/etc/zprofile` that runs `/usr/libexec/path_helper`, which rebuilds
PATH and hoists `/usr/bin` to the front. A `brew shellenv` in `~/.zshenv` runs before
that and is silently undone, leaving you on Apple's `git`, `curl` and `jq` even though
the Homebrew ones are installed. Running it from `~/.zprofile` (after `path_helper`)
is what actually makes Homebrew win. If you add PATH entries of your own and expect
them to beat the system ones on macOS, put them in `.zprofile` too.

**`typeset -U path PATH` is set in `.zshenv`.** This setup nests login shells on
purpose (WezTerm spawns `$SHELL -l`, tmux spawns `$SHELL -l` again per pane), so
without de-duplication PATH grows at every nesting level. macOS hides this via
`path_helper`; Ubuntu does not, so it is made explicit for both.

**The completion dump is cached for 24 hours.** `compinit` rescans `fpath` and
rewrites `~/.cache/zsh/.zcompdump-<version>` on every shell start by default,
which is the most expensive thing in `.zshrc`. It now does the full scan at most
once a day and uses `compinit -C` otherwise. If you install a tool that ships
new shell completions and they do not show up, drop the cache:

```bash
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/zsh/.zcompdump-*
```

Plugins are loaded **before** `compinit`, because `compinit` only sees the
`fpath` it is given at call time. If you add a plugin that ships completions,
it must go in `.zsh_plugins.txt`, not below the completion block.

macOS-only configs (Alacritty, etc.) live in `mac/configs/.config/` and are symlinked separately by `mac/dotfiles.sh`.

### Editing configs

```bash
# edit from anywhere
$EDITOR ~/Projects/devsetup/dotfiles/.config/nvim/init.lua

# commit and push -- both machines pick it up on next git pull
cd ~/Projects/devsetup
git commit -am "nvim: add keymap for telescope"
git push
```

### Pulling changes on the other machine

```bash
cd ~/Projects/devsetup
git pull
# dotfiles are symlinks -- changes are live immediately, no re-run needed
# unless you added a new dotfile that requires a new symlink:
./mac/run.sh --only dotfiles   # or ./linux/run.sh --only dotfiles
```

---

## Git configuration

`dotfiles/.gitconfig` is symlinked to `~/.gitconfig` and includes
`~/.gitconfig.local` at the end, which is where your name, email and
credential helper live. That file is machine-local and never committed; the
`configure` step writes it for you.

Opinionated defaults worth knowing about:

| Setting | Effect |
|---|---|
| `pull.rebase = true` | `git pull` rebases, never merges |
| `rerere.enabled = true` | Conflict resolutions are recorded and replayed on the next rebase |
| `push.default = current` + `push.autoSetupRemote` | `git push` on a new branch just works, no `--set-upstream` |
| `fetch.prune = true` | Deleted upstream branches disappear locally on fetch |
| `merge.conflictstyle = zdiff3` | Conflict markers include the common ancestor |
| `init.defaultBranch = main` | |

`format.pretty` and `diff.word-diff` are deliberately **not** set globally.
Both look appealing but apply far wider than intended: `format.pretty` also
governs `git show`, where a one-line format hides the commit body and author,
and a global `word-diff` makes `git diff` output stop round-tripping through
`git apply`. Use the `l` / `lg` and `dw` aliases instead.

Note that git silently ignores any alias that shadows a builtin, so `add`,
`diff`, `pull`, `remote` and `tag` cannot be aliased. Those are `rv` and `ta`
here; `pull` and `diff` behaviour comes from config instead.

**The global gitignore is deliberately small.** `dotfiles/.gitignore_global`
covers OS metadata, editor scratch files and local tool state only. Build
output and language artefacts are a property of the project, not the machine,
and belong in the project's own `.gitignore`.

This is a change in policy: the file used to be a 1040-line gitignore.io dump
covering 20+ languages, which globally ignored `pom.xml`, `Cargo.lock`,
`bower.json`, `target/`, `build/`, `lib/`, `bin/`, `dist/` and `out/`. Files
matching those patterns silently failed to be added in *every* repository on
the machine. If you were relying on that, add the patterns to the individual
projects that need them.

---

## Coding agents

`dotfiles/.config/agents/instructions.md` is the shared system prompt for all three agents:

| Agent | Config location |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` → symlinked to `agents/instructions.md` |
| Codex | `~/.codex/config.toml` -- model `o4-mini`, written by agents step |
| OpenCode | `~/.config/opencode/config.json` -- written by agents step |

Edit `dotfiles/.config/agents/instructions.md` to update instructions for all agents at once.

---

## Versions

Runtime versions are pinned in platform-specific `versions.txt` files:

- `mac/versions.txt` -- Neovim, mise, Node, Nerd Fonts
- `linux/versions.txt` -- Neovim, mise, Node, Go, Python, Rust, Nerd Fonts, IaC tools

Global mise tool versions (Python, Node, Go) are in `dotfiles/.config/mise/config.toml` and override these defaults per-project via `.mise.toml` files.

---

## Post-install state

Most tools work immediately after the run completes. Two things require a session restart:

| Trigger | Reason | Action |
|---|---|---|
| **New login shell** | `chsh`/`usermod` changes only apply on next login | Log out and back in |
| **New terminal window** | Homebrew/mise PATH additions are sourced from `.zshenv` | Open a fresh terminal |

Everything else is live without restart:
- Dotfile changes take effect in the next new shell (symlinks are immediate)
- Neovim plugins are bootstrapped headlessly by the `editor` step
- Tmux plugins are installed by the `multiplexer` step (TPM runs at next `tmux` start)
- Agent configs (CLAUDE.md, config.toml, config.json) are written and ready

**Dotfiles step on a machine with existing configs:** existing files are backed up to `~/.local/state/devsetup/dotfiles-backups/<timestamp>/` before being replaced with symlinks.

---

## Verification

```bash
# macOS
cd ~/Projects/devsetup/mac && ./run.sh --verify

# Linux
cd ~/Projects/devsetup/linux && ./run.sh --verify
```

---

## Adding a new tool

**Homebrew (macOS):** add to `mac/Brewfile`, then `brew bundle`.

**APT (Linux):** add to `linux/system/apt-packages.txt`, then `sudo apt-get install <pkg>`.

**GitHub release binary (Linux):** add a line to `linux/system/github-tools.txt` in the format `command|owner/repo|asset_regex|mode|binary`.

**Both platforms:** if it's a mise-managed runtime, add to `dotfiles/.config/mise/config.toml`. If it's a CLI tool available via both Homebrew and APT, add to both `mac/Brewfile` and `linux/system/apt-packages.txt`.

---

## Extending

- **New macOS step:** add a script under `mac/<stepname>/<stepname>.sh`, wire it into `mac/run.sh` steps array.
- **New Linux step:** add a script under `linux/<stepname>/<stepname>.sh`, wire it into `linux/run.sh` steps array.
- **Shared config:** add files under `dotfiles/` -- they are automatically symlinked by both platform dotfiles scripts.
- **macOS-only config:** add under `mac/configs/.config/<toolname>/` -- symlinked by `mac/dotfiles.sh`.

