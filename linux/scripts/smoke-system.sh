#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "${LINUX_SETUP_SMOKE_FULL:-0}" != "1" ]]; then
    export LINUX_SETUP_SKIP_SNAPS="${LINUX_SETUP_SKIP_SNAPS:-1}"
    export LINUX_SETUP_SKIP_CHROME="${LINUX_SETUP_SKIP_CHROME:-1}"
    export LINUX_SETUP_SKIP_GO="${LINUX_SETUP_SKIP_GO:-1}"
    export LINUX_SETUP_SKIP_PYTHON="${LINUX_SETUP_SKIP_PYTHON:-1}"
    export LINUX_SETUP_SKIP_RUST="${LINUX_SETUP_SKIP_RUST:-1}"
    export LINUX_SETUP_SKIP_UFW="${LINUX_SETUP_SKIP_UFW:-1}"
fi

# These tools are installed by separate steps (editor/terminal), not by
# system.sh.  Always skip their verification in the system smoke so that
# verify-system-smoke.sh doesn't require them when run from this script.
export LINUX_SETUP_SKIP_NEOVIM="${LINUX_SETUP_SKIP_NEOVIM:-1}"
export LINUX_SETUP_SKIP_WEZTERM="${LINUX_SETUP_SKIP_WEZTERM:-1}"
export LINUX_SETUP_SKIP_FONTS="${LINUX_SETUP_SKIP_FONTS:-1}"

echo "==> Running system smoke install"
bash run.sh --only system

echo "==> Verifying system smoke install"
bash scripts/verify-system-smoke.sh
