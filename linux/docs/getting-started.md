# Getting Started

## Intended Flow

The default order is:

1. `system`
2. `dotfiles`
3. `configure`
4. `shell`
5. `editor`
6. `multiplexer`
7. `terminal`
8. `sdk`
9. `agents`

That order is already encoded in `./run.sh`, so a plain `./run.sh` is the normal entrypoint on a fresh machine.

## Base Install

Install Git, clone the repository, and run:

```bash
./run.sh
```

This path is meant to work for a generic Ubuntu developer workstation with `sudo` access.

For unattended execution, pass Git identity so the configure step is non-blocking:

```bash
LINUX_SETUP_GIT_NAME="Your Name" LINUX_SETUP_GIT_EMAIL="you@example.com" ./run.sh
```

## Optional Steps

Default run includes all steps, including:

- GitHub SSH setup (`git`)
- GNOME desktop preferences (`settings`)

If you want a non-interactive or server-style path, skip them:

```bash
./run.sh --skip-git --skip-settings
```

## Running Individual Steps

Use `--only` when you want to rerun or isolate a module:

```bash
./run.sh --only system
./run.sh --only dotfiles
./run.sh --only configure
./run.sh --only agents
```

`run.sh` will warn when you select a step without its usual dependency.

## Verification

To check the installed toolchain without making changes:

```bash
./run.sh --verify
```

For repository gates:

```bash
bash scripts/test.sh
```

Every `run.sh` execution writes a timestamped log by default:

- `~/.local/state/devsetup/logs/run-YYYYMMDD-HHMMSS.log`

If that location is not writable, `run.sh` automatically falls back to:

- `${TMPDIR:-/tmp}/devsetup-logs/run-YYYYMMDD-HHMMSS.log`

You can set a custom path explicitly:

```bash
LINUX_SETUP_LOG_FILE="$HOME/.local/state/devsetup/logs/my-run.log" ./run.sh
```

## After Bootstrap

Typical follow-up actions:

- open a new shell so `mise` and shell changes are active everywhere
- pick your zsh profile (`antidote-p10k` by default, or `zsh4humans`)
- review generated MCP configs and add your own API tokens if needed
- rerun any optional steps you intentionally skipped the first time
- adjust manifests or dotfiles only after the base install is stable
