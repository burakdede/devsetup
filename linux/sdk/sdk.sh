#!/usr/bin/env bash
# SDKMAN bootstrap for Ubuntu.
#
# The logic is OS-neutral and lives in shared/sdk.sh; this wrapper only supplies
# the paths. SDKMAN owns the JVM ecosystem (JDKs including GraalVM, Maven,
# Gradle, Kotlin, Scala, Groovy, sbt, Spring Boot CLI, Grails); mise owns every
# other runtime.
#
# ── Adding or pinning a candidate ─────────────────────────────────────────────
# Edit packages/sdkman.txt at the repo root, then: ./run.sh --only sdk
# Find version identifiers with: sdk list <candidate>
#
# ── Upgrading SDKMAN itself ───────────────────────────────────────────────────
#   sdk selfupdate
#
# Skip: MACHINIST_SKIP_SDK=1 ./run.sh --only sdk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../utils/utils.sh
source "$SCRIPT_DIR/../utils/utils.sh"

trap 'handle_error $? $LINENO' ERR

if should_skip_step SDK; then
    log_info "Skipping SDKMAN (MACHINIST_SKIP_SDK is set)."
    exit 0
fi

# Shared with the other platform -- see packages/sdkman.txt.
PACKAGES_FILE="$REPO_ROOT/packages/sdkman.txt"

# shellcheck source=../../shared/sdk.sh
source "$REPO_ROOT/shared/sdk.sh"
setup_sdkman "$@"
