#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# DEVSETUP_* is the documented prefix on both platforms; should_skip_step and
# verify-system-smoke.sh both read it, so only one spelling needs exporting.
if [[ "${DEVSETUP_SMOKE_FULL:-${LINUX_SETUP_SMOKE_FULL:-0}}" != "1" ]]; then
    export DEVSETUP_SKIP_SNAPS="${DEVSETUP_SKIP_SNAPS:-1}"
    export DEVSETUP_SKIP_CHROME="${DEVSETUP_SKIP_CHROME:-1}"
    export DEVSETUP_SKIP_RUST="${DEVSETUP_SKIP_RUST:-1}"
    export DEVSETUP_SKIP_UFW="${DEVSETUP_SKIP_UFW:-1}"
fi

# These tools are installed by separate steps (editor/terminal), not by
# system.sh.  Always skip their verification in the system smoke so that
# verify-system-smoke.sh doesn't require them when run from this script.
export DEVSETUP_SKIP_NEOVIM="${DEVSETUP_SKIP_NEOVIM:-1}"
export DEVSETUP_SKIP_WEZTERM="${DEVSETUP_SKIP_WEZTERM:-1}"
export DEVSETUP_SKIP_FONTS="${DEVSETUP_SKIP_FONTS:-1}"

echo "==> Running system smoke install"
bash run.sh --only system

echo "==> Verifying system smoke install"
bash scripts/verify-system-smoke.sh
