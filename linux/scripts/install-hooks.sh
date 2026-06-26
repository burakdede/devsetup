#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push scripts/test.sh

echo "Configured local git hooks at .githooks"
echo "pre-commit and pre-push will now run scripts/test.sh"
