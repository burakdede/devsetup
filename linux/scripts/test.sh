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
# Also shellcheck shared dotfiles shell files from the monorepo root
for f in "$REPO_ROOT/dotfiles/.bash_aliases" "$REPO_ROOT/dotfiles/.zshenv"; do
    [[ -f "$f" ]] && shellcheck_scripts+=("$f")
done
shellcheck "${shellcheck_scripts[@]}"

echo "==> unittest"
python3 -m unittest discover -s tests -p 'test_*.py' -v
