# machinist tasks.
#
# `just` with no arguments lists everything. These are the commands worth
# having a short name for -- the ones you or an agent reach for repeatedly.

_default:
    @just --list --unsorted

# Full health check: what is installed, wired and working.
verify:
    ./install.sh --verify

# Everything that keeps the machine current, in one pass.
update: update-system update-editor update-hooks
    @echo "Everything updated. Run 'just verify' to confirm."

# Package managers and runtimes.
update-system:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v brew >/dev/null 2>&1; then
        brew update && brew upgrade && brew cleanup -s
    fi
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y
    fi
    # mise reads the pinned versions from dotfiles/.config/mise/config.toml,
    # so this installs what is declared rather than drifting to latest.
    "$HOME/.local/bin/mise" install
    command -v uv >/dev/null 2>&1 && uv tool upgrade --all
    [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ] && \
        bash -c 'set +u; source "$HOME/.sdkman/bin/sdkman-init.sh"; sdk selfupdate || true'

# Neovim plugins, treesitter parsers and LSP servers.
update-editor:
    nvim --headless "+Lazy! sync" +qa
    nvim --headless "+TSUpdate" +qa
    nvim --headless "+MasonUpdate" +qa
    @echo "Editor updated."

# pre-commit hook revisions.
update-hooks:
    pre-commit autoupdate
    pre-commit install-hooks

# The full test suite: shellcheck, zsh parse, unit tests.
test:
    cd linux && bash scripts/test.sh

# Run every formatter and linter across the repo.
fmt:
    pre-commit run --all-files

# Re-link dotfiles after adding a new one.
link:
    ./install.sh --only dotfiles

# What changed in the shell config since the last commit.
diff:
    git diff -- dotfiles/

# Measure interactive shell startup, both shells.
bench:
    #!/usr/bin/env bash
    for sh in zsh bash; do
        command -v "$sh" >/dev/null 2>&1 || continue
        best=99
        for _ in 1 2 3 4 5; do
            t=$( { /usr/bin/time -p "$sh" -lic 'exit' ; } 2>&1 | awk '/^real/{print $2}' )
            best=$(awk -v a="$t" -v b="$best" 'BEGIN{print (a<b)?a:b}')
        done
        printf '%-5s %sms\n' "$sh" "$(awk -v b="$best" 'BEGIN{printf "%d", b*1000}')"
    done
