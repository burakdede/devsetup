# Verification and CI

[← back to README](../README.md)

## Verification

```bash
./install.sh --verify   # from anywhere in the clone
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
| `macos-ci.yml` | `macos-15` | shellcheck, zsh parse, Brewfile validity and resolution, plus the dotfiles / configure / agents steps for real |

macOS deliberately does not run the full `system` step: installing every cask
in the Brewfile is far too slow for a hosted runner. Both workflows also run
weekly, to catch upstream breakage (a removed Homebrew flag, a renamed GitHub
release asset, a vendor archive that moves) rather than discovering it
mid-install on a new machine.

Because the `system` step is skipped there, `mac/scripts/check-brewfile.sh`
covers the part of it that fails most often. It asks Homebrew whether every
Brewfile entry still exists, is the kind it is declared as, and has not been
renamed upstream. A rename is not a warning you can ignore: `brew bundle
install` fails on it, and that aborts the system step partway through a fresh
machine's bootstrap. The check reads metadata only and installs nothing, so it
costs seconds rather than the hour a real `brew bundle` would.

Run the Linux suite locally with `cd linux && bash scripts/test.sh`.

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

**Dotfiles step on a machine with existing configs:** existing files are backed up to `~/.local/state/machinist/dotfiles-backups/<timestamp>/` before being replaced with symlinks.
