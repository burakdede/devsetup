#!/usr/bin/env bash
# Point this repo's git at .githooks/, so commits and pushes are checked.
#
# The hooks run pre-commit (shellcheck, ruff, yamllint, secret scanning) and
# then the bootstrap test suite. Both degrade gracefully when their tools are
# missing, so this is safe to run before a full bootstrap.
#
# Idempotent. Called by install.sh; run it directly after cloning if you only
# want the hooks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d .git ]; then
    echo "Not a git checkout: $REPO_ROOT" >&2
    exit 1
fi

# core.hooksPath is resolved relative to the REPO ROOT, not to whatever
# directory this script happens to run from. That was the original bug: this
# lived in linux/scripts/ and set the path to '.githooks', which git looked for
# at the repo root while the directory was linux/.githooks. The hooks silently
# never fired.
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push

echo "git hooks active: $(git config core.hooksPath)"
