#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_NAME="devsetup-smoke"
KEEP_VM=0
FULL_SMOKE=0

usage() {
    cat <<'EOF'
Usage: bash scripts/vm-smoke-test.sh [options]

Options:
  --name NAME   Override the VM name.
  --keep        Keep the VM after the smoke test finishes.
  --full        Run the fuller smoke profile instead of the default lighter one.
  --help        Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            shift
            VM_NAME="$1"
            ;;
        --keep)
            KEEP_VM=1
            ;;
        --full)
            FULL_SMOKE=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

if ! command -v multipass >/dev/null 2>&1; then
    echo "multipass is required for VM smoke testing." >&2
    exit 1
fi

cleanup() {
    if [[ "$KEEP_VM" -eq 0 ]]; then
        multipass delete "$VM_NAME" >/dev/null 2>&1 || true
        multipass purge >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if multipass info "$VM_NAME" >/dev/null 2>&1; then
    multipass delete "$VM_NAME"
    multipass purge
fi

echo "==> Launching Multipass VM: $VM_NAME"
multipass launch 24.04 --name "$VM_NAME" --cpus 2 --memory 4G --disk 20G

echo "==> Copying repository into VM"
multipass exec "$VM_NAME" -- rm -rf /home/ubuntu/devsetup
multipass transfer -r "$ROOT_DIR" "$VM_NAME:/home/ubuntu/devsetup"

SMOKE_ENV=""
if [[ "$FULL_SMOKE" -eq 1 ]]; then
    SMOKE_ENV="LINUX_SETUP_SMOKE_FULL=1"
fi

echo "==> Running smoke tests in VM"
multipass exec "$VM_NAME" -- bash -lc "
  sudo apt-get update &&
  sudo apt-get install -y shellcheck python3 &&
  cd /home/ubuntu/devsetup &&
  bash scripts/test.sh &&
  ${SMOKE_ENV} bash scripts/smoke-system.sh
"

echo "VM smoke test passed"
if [[ "$KEEP_VM" -eq 1 ]]; then
    echo "VM kept as: $VM_NAME"
fi
