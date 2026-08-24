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

### Environment variables

The same names work on both platforms:

| Variable | Effect |
|---|---|
| `DEVSETUP_SKIP_<STEP>=1` | Skip one step, e.g. `DEVSETUP_SKIP_SDK=1` |
| `DEVSETUP_UPGRADE=1` | Re-install tools even when already present |
| `DEVSETUP_GIT_NAME` / `_EMAIL` | Pre-seed git identity for an unattended run |
| `DEVSETUP_LOG_FILE` | Override the run log path |
| `DEVSETUP_PROMPT_TIMEOUT_SECONDS` | Timeout for interactive prompts (default 60) |

The older `MACSETUP_*` and `LINUX_SETUP_*` spellings still work, but they were
gratuitously different between the two machines. Genuinely Ubuntu-only knobs
(GNOME fonts, cursor size, wallpapers) keep the `LINUX_SETUP_*` prefix, since
they have no macOS counterpart.

A fully unattended install:

```bash
DEVSETUP_GIT_NAME="Your Name" DEVSETUP_GIT_EMAIL="you@example.com" \
  ./run.sh --skip-git
```

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
Skip a step: `DEVSETUP_SKIP_SDK=1 ./run.sh`  
Re-install: `DEVSETUP_UPGRADE=1 ./run.sh --only editor`

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
Skip a step: `DEVSETUP_SKIP_SDK=1 ./run.sh`  
Re-install: `DEVSETUP_UPGRADE=1 ./run.sh --only editor`

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

**`LC_ALL` is not set, only `LANG`.** `LC_ALL` overrides every `LC_*` category
at once and outranks `LANG`, so setting it discards the region you chose in
System Settings or `localectl`. An `en_GB` machine would still get US date and
number formats. Pin it per command when you need to: `LC_ALL=C sort`.

**`pbcopy` / `pbpaste` work on both machines.** They are macOS built-ins; on
Linux they are aliased to `wl-copy`/`wl-paste` under Wayland or `xclip` under
X11, so the same commands and the same scripts work either side.

**fzf is backed by `fd`** via `FZF_DEFAULT_COMMAND`, so it honours `.gitignore`
and skips `.git` instead of shelling out to `find` and walking `node_modules`.
Shell integration comes from `fzf --zsh` where available (0.48+), falling back
to the packaged scripts on older Ubuntu builds.

**`bat` is not aliased over `cat`,** deliberately: it adds decorations that
break piping and copy-paste. It is wired in only where it is unambiguously
better, as `MANPAGER` for syntax-highlighted man pages and as the preview
window for fzf's Ctrl-T.

**`delta` is the git pager,** configured in `.gitconfig`. The setting is
guarded with a `command -v` fallback to `less`, because git treats a missing
pager as a fatal error and this file is symlinked on machines where the system
step may not have run yet.

**SDKMAN is loaded lazily.** `sdkman-init.sh` loops over every installed
candidate in shell to build PATH, which costs ~90ms per shell with ten
candidates -- around 40% of total startup. `.zshrc` instead globs
`~/.sdkman/candidates/*/current/bin` onto PATH directly and sets `JAVA_HOME`,
so `java`, `kotlin`, `scala` and friends are available immediately, and defers
the real init until the first time you actually run `sdk`. The `sdk` stub
replaces itself on first call, so everything (`sdk list`, `sdk use`, `sdk env`)
behaves normally.

Interactive shell startup is roughly **100ms** as a result, down from 210ms.

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

## Terminal

WezTerm on both platforms, with `disable_default_key_bindings = true` so that
nothing intercepts the Ctrl combinations readline and zsh rely on (Ctrl+R
history search, Ctrl+W kill-word, Ctrl+K kill-line). The bindings are then
declared explicitly, using each platform's native modifier: **Cmd** on macOS,
**Ctrl+Shift** on Linux. Written below as `<mod>`.

| Keys | Action |
|---|---|
| `<mod>` + C / V | Copy / paste |
| `<mod>` + T / W | New tab / close tab |
| `<mod>` + 1..8 | Jump to tab; `<mod>` + 9 jumps to the last |
| Ctrl + Tab | Next tab (Shift for previous) |
| `<mod>` + E / O | Split horizontally / vertically |
| `<mod>` + Shift + H/J/K/L | Move between panes |
| `<mod>` + Z | Zoom pane |
| `<mod>` + K | Clear scrollback |
| `<mod>` + F / X | Search / copy mode |

Because the defaults are off, a binding that is not in `wezterm.lua` does not
exist. If something you expect is missing, add it there rather than assuming
WezTerm provides it.

**Linux uses the native Wayland backend** when the session is Wayland, rather
than falling back to XWayland. XWayland costs fractional scaling and gives
blurry text on HiDPI, which is the common case on modern GNOME. If your
compositor misbehaves, export `WEZTERM_DISABLE_WAYLAND=1` in `~/.zshrc.local`.

---

## Neovim

Plugins are managed by lazy.nvim and pinned in
`dotfiles/.config/nvim/lazy-lock.json`. Update with `:Lazy update`, then commit
the lock file so both machines move together.

### treesitter is on the `main` branch

This matters, because `main` is a **full, incompatible rewrite** of
nvim-treesitter and most guidance you will find online is for `master`. On
`main`:

- `ensure_installed`, `highlight = { enable = true }`, `indent`, and
  `auto_install` **do not exist**. Writing them is silently ignored, which
  leaves you with Vim's regex syntax and no treesitter at all.
- Parsers are installed with `require("nvim-treesitter").install{...}`.
- Highlighting is turned on per buffer with `vim.treesitter.start()`, which the
  config does from a `FileType` autocommand.
- It needs **Neovim >= 0.12** and the **`tree-sitter` CLI >= 0.26.1**, which
  master never required. Upstream is explicit that it must come from a package
  manager and **not npm**, so it is `tree-sitter-cli` in the Brewfile on macOS
  and a release binary via `github-tools.txt` on Ubuntu.

### Language servers come from Mason

Mason is a package manager for LSP servers that lives inside Neovim. It exists
here for one reason: it is the only place macOS and Ubuntu converge for free.
Installing servers natively would mean four mechanisms for four servers
(`brew`, `go install`, `npm -g`, `rustup component`), each different per OS.
Mason turns that into one list that resolves identically on both machines.

The tradeoff is a second package manager alongside brew/apt/mise, and servers
that only exist inside Neovim. That is the right trade for this setup, but it
is a real one.

### Everyday Neovim workflows

| Task | How |
|---|---|
| Add a language server | Add the lspconfig name to `servers` in `lua/plugins/lsp.lua`, restart. Mason installs it |
| Add a treesitter parser | Add the parser name to `parsers` in the same file, restart |
| Update plugins | `:Lazy update`, then commit `lazy-lock.json` so both machines match |
| Update parsers | `:TSUpdate` |
| See what is installed | `:Mason`, `:checkhealth nvim-treesitter`, `:checkhealth vim.lsp` |
| Diagnose a slow start | `nvim --startuptime /tmp/st && sort -k2 -rn /tmp/st \| head` |

Plugin versions are pinned in `lazy-lock.json`. Commit it after any `:Lazy
update`; that file is what keeps the two machines on identical plugin versions.

---

## Terminal input problems

If typing into the terminal produces duplicated characters, stray spaces, or
runaway key repeat, work through these in order. All three have bitten this
setup.

**1. Key repeat set too aggressively (macOS).** This was self-inflicted:
`os-defaults.sh` used to set `KeyRepeat=1` (15ms, ~67 chars/sec) and
`InitialKeyRepeat=10` (150ms), both faster than System Settings can express. A
150ms delay sits *inside* the normal 70-150ms dwell time of a keypress, so
ordinarily-held keys began repeating. Check with:

```bash
defaults read -g KeyRepeat          # want 2  (30ms)
defaults read -g InitialKeyRepeat   # want 15 (225ms)
```

Ubuntu's equivalents are set to match, so both machines type alike:

```bash
gsettings get org.gnome.desktop.peripherals.keyboard delay            # want 225
gsettings get org.gnome.desktop.peripherals.keyboard repeat-interval  # want 30
```

Both take effect only for applications started after the change.

**2. iBus XIM double-processing (Ubuntu).** On X11, `XMODIFIERS=@im=ibus`
makes WezTerm connect to the iBus XIM server, which processes each key event
twice: duplicated and dropped keystrokes. `use_ime = false` alone does not fix
it, because that stops IME *composition*, not the XIM *connection*.

The fix is clearing `XMODIFIERS` before WezTerm starts, and it must cover
**every** launch path, not just the app launcher:

| Launch path | Covered by |
|---|---|
| GNOME launcher / dock | `~/.local/share/applications/*.desktop` override |
| Ctrl+Alt+T, "Open in Terminal" | `/usr/local/bin/wezterm-terminal` wrapper |
| `x-terminal-emulator` | the same wrapper |

Check it is actually clear inside a running WezTerm:

```bash
echo "[$XMODIFIERS]"    # want [] -- if it shows @im=ibus, this path is unpatched
```

**3. Native Wayland backend (Ubuntu).** WezTerm has an open upstream report of
duplicate keystrokes under Wayland. This setup prefers the native backend, for
fractional scaling and crisp HiDPI text. If input misbehaves on Wayland, fall
back to XWayland:

```bash
echo 'export WEZTERM_DISABLE_WAYLAND=1' >> ~/.zshrc.local
```

Note what is deliberately **not** changed: `use_ime` is left at its default
(enabled) on macOS. WezTerm's IME key-repeat bug was fixed in 20220319 and this
setup runs a later build, so disabling it would cost accented and CJK input for
no gain.

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

---

## Versions

Every version is pinned in exactly one place, shared by both platforms.

| Pinned in | Covers |
|---|---|
| `dotfiles/.config/mise/config.toml` | Everything mise manages: Python, Node, Go, Terraform, tflint, Terragrunt, terraform-docs |
| `packages/versions.txt` | Everything mise does not: Neovim, mise itself, Rust toolchain, Nerd Fonts |

There are no per-platform `versions.txt` files. Both machines resolve the same
pins, so `node --version` gives the same answer on each.

**Do not run `mise use --global`.** It rewrites `~/.config/mise/config.toml`,
which is a symlink into this repo, so it would silently edit tracked config.
The setup scripts run `mise install`, which only reads. To change a runtime
version, edit `dotfiles/.config/mise/config.toml` and commit it.

Per-project overrides still work normally through a project's own `.mise.toml`
or `.tool-versions`.

### mise trust

mise discovers config by walking **up from the current directory**, looking for
`.config/mise/config.toml` in each ancestor. Because our copy lives at
`<repo>/dotfiles/.config/mise/config.toml`, the moment you `cd` into the
dotfiles directory to edit something -- the workflow this repo is built around
-- mise finds it as a *project* config rather than the global one.

Project configs need explicit trust, while `~/.config/mise/config.toml` is
trusted implicitly. Untrusted, every mise command run from inside the repo
fails with:

```
mise ERROR Config files in .../dotfiles/.config/mise/config.toml are not trusted.
```

The `dotfiles` step grants that trust for you. Trust is recorded per machine
under `~/.local/state/mise/trusted-configs`, so it cannot be committed and has
to be granted once on each machine. If you ever hit the error, either re-run
`./run.sh --only dotfiles` or do it directly:

```bash
mise trust ~/Projects/devsetup/dotfiles/.config/mise/config.toml
```

`--verify` checks this and fails if the config is untrusted.

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

Prints a pass/fail/warn table. The cross-platform checks live in
`shared/verify.sh` and are **derived from the manifests** rather than
hand-listed, so a tool added to `packages/` is verified automatically and the
verifier cannot drift from the installer.

## CI

Both platforms are covered:

| Workflow | Runner | What it does |
|---|---|---|
| `linux-ci.yml` | `ubuntu-24.04` | shellcheck, zsh parse, 30 unit tests, plus a **real** system bootstrap (APT, mise, Docker, runtimes) |
| `macos-ci.yml` | `macos-15` | shellcheck, zsh parse, Brewfile validity, plus the dotfiles / configure / agents steps for real |

macOS deliberately does not run the full `system` step: installing every cask
in the Brewfile is far too slow for a hosted runner. Both workflows also run
weekly, to catch upstream breakage (a removed Homebrew flag, a renamed GitHub
release asset, a snap that disappears) rather than discovering it mid-install
on a new machine.

Run the Linux suite locally with `cd linux && bash scripts/test.sh`.

---

## What this setup decides for you

It is opinionated. If you are adopting it, these are the choices you are
inheriting.

| Concern | Choice | Why |
|---|---|---|
| Shell | zsh + antidote + powerlevel10k | Fast, no framework; plugins are a plain text list |
| Runtimes | mise, one shared config | Python, Node, Go, and the IaC tooling in one pinned file |
| JVM | SDKMAN | Better JVM story than mise: vendors, GraalVM, per-project `sdk use` |
| Python CLIs | uv | Isolated tool installs, no global pip |
| Terminal | WezTerm | Same config and same keys on both platforms |
| Multiplexer | tmux, OSC 52 clipboard | Copy behaves identically on macOS and Ubuntu, and over SSH |
| Editor | Neovim + lazy.nvim, treesitter `main` branch | |
| Prompt | powerlevel10k with instant prompt | |

**One runtime manager, not several.** mise owns Python, Node and Go; SDKMAN
owns the JVM. `pyenv`, `rbenv`, `nodenv`, `nvm`, `asdf`, `goenv` and `jenv` all
shadow the mise shims for the same runtime, and which version you get then
depends on PATH order rather than on the config in this repo. `--verify` warns
when it finds one, and reports whether `node` and `python` actually resolve
through mise.

If you are migrating from one of them, uninstall it rather than leaving it
alongside mise, and move its pinned versions into
`dotfiles/.config/mise/config.toml` first:

```bash
brew uninstall pyenv rbenv && rm -rf ~/.pyenv ~/.rbenv
```

**Agent skills are not vendored here.** Claude Code loads skills from
`~/.claude/skills` and its own plugin cache, never from
`~/.config/agents/skills`. Anything copied there is dead weight that the plugin
cache regenerates, so it is gitignored. Only `instructions.md` is shared.

**The Brewfile is the source of truth for macOS packages.** If you install
things by hand it will drift, and `--verify` will tell you so. Reconcile with
`brew bundle install --file=mac/Brewfile`, or add what you installed to the
Brewfile. GUI apps you do not want are worth deleting from the Brewfile rather
than leaving permanently unsatisfied.

**Nothing here pins an LLM model id.** Agent configs use each CLI's own
default; see the Coding agents section.

---

## Adding a new tool

**Homebrew (macOS):** add to `mac/Brewfile`, then `brew bundle`.

**APT (Linux):** add to `linux/system/apt-packages.txt`, then `sudo apt-get install <pkg>`.

**GitHub release binary (Linux):** add a line to `linux/system/github-tools.txt` in the format `command|owner/repo|asset_regex|mode|binary`.

**Both platforms:** prefer a shared manifest so the two machines cannot drift.

| Kind of tool | Add it to |
|---|---|
| Language runtime or IaC tool | `dotfiles/.config/mise/config.toml` |
| Python CLI | `packages/uv-tools.txt` |
| Node CLI | `packages/npm-packages.txt` |
| JVM SDK | `packages/sdkman.txt` |
| Version pin for something mise does not manage | `packages/versions.txt` |

Only reach for `mac/Brewfile` or `linux/system/apt-packages.txt` when the tool
genuinely has no cross-platform installer, and then add it to **both**. Adding a
cross-platform tool to one OS list only is the usual way the machines diverge.

---

## Extending

- **New macOS step:** add a script under `mac/<stepname>/<stepname>.sh`, wire it into `mac/run.sh` steps array.
- **New Linux step:** add a script under `linux/<stepname>/<stepname>.sh`, wire it into `linux/run.sh` steps array.
- **Shared config:** add files under `dotfiles/` -- they are automatically symlinked by both platform dotfiles scripts.
- **macOS-only config:** add under `mac/configs/.config/<toolname>/` -- symlinked by `mac/dotfiles.sh`.

