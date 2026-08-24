#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "==> bash -n"
mapfile -t shell_scripts < <(
    git -C "$ROOT_DIR" ls-files '*.sh' '.githooks/pre-commit' '.githooks/pre-push'
)
bash -n "${shell_scripts[@]}"

echo "==> shellcheck"
mapfile -t shellcheck_scripts < <(
    git -C "$ROOT_DIR" ls-files '*.sh' '*.bash' '.githooks/pre-commit' '.githooks/pre-push'
)
# Shared bash sourced by both platforms lives at the monorepo root.
while IFS= read -r f; do
    shellcheck_scripts+=("$REPO_ROOT/$f")
done < <(git -C "$REPO_ROOT" ls-files 'shared/*.sh')

# -x follows `source` directives so the shared/ files are resolved rather than
# reported as SC1091. The zsh dotfiles are NOT linted here: shellcheck has no
# zsh support, and .zshenv/.zshrc use zsh-only syntax (typeset -U, path arrays)
# that it would misreport as bash errors. They are syntax-checked below.
shellcheck -x --source-path=SCRIPTDIR "${shellcheck_scripts[@]}"

echo "==> zsh -n (zsh dotfiles)"
if command -v zsh >/dev/null 2>&1; then
    for f in "$REPO_ROOT"/dotfiles/.zshenv "$REPO_ROOT"/dotfiles/.zshrc "$REPO_ROOT"/dotfiles/.zprofile; do
        [[ -f "$f" ]] || continue
        zsh -n "$f" || exit 1
        echo "    ok  ${f#"$REPO_ROOT"/}"
    done
else
    echo "    zsh not installed; skipping"
fi

echo "==> unittest"
python3 -m unittest discover -s tests -p 'test_*.py' -v
