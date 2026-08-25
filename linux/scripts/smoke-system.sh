#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# MACHINIST_* is the documented prefix on both platforms; should_skip_step and
# verify-system-smoke.sh both read it, so only one spelling needs exporting.
if [[ "${MACHINIST_SMOKE_FULL:-0}" != "1" ]]; then
    export MACHINIST_SKIP_CHROME="${MACHINIST_SKIP_CHROME:-1}"
    export MACHINIST_SKIP_RUST="${MACHINIST_SKIP_RUST:-1}"
    export MACHINIST_SKIP_UFW="${MACHINIST_SKIP_UFW:-1}"
fi

# These tools are installed by separate steps (editor/terminal), not by
# system.sh.  Always skip their verification in the system smoke so that
# verify-system-smoke.sh doesn't require them when run from this script.
export MACHINIST_SKIP_NEOVIM="${MACHINIST_SKIP_NEOVIM:-1}"
export MACHINIST_SKIP_WEZTERM="${MACHINIST_SKIP_WEZTERM:-1}"
export MACHINIST_SKIP_FONTS="${MACHINIST_SKIP_FONTS:-1}"

echo "==> Running system smoke install"
bash run.sh --only system

echo "==> Verifying system smoke install"
bash scripts/verify-system-smoke.sh
