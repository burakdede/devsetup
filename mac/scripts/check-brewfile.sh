#!/usr/bin/env bash
# Validate every Brewfile entry against Homebrew, without installing anything.
#
# `brew bundle list` only parses the file. It cannot tell you that an entry no
# longer exists, or that upstream renamed it -- and a rename is not a warning
# you get to ignore: `brew bundle install` fails on it, which aborts the whole
# system step partway through a fresh machine's bootstrap.
#
# That happened during the Brewfile reconciliation: the cask `google-cloud-sdk`
# had become `gcloud-cli`, and it was caught only because someone ran
# `brew bundle check` by hand.
#
# Installing the Brewfile in CI would catch it too, but installing GUI casks on
# a hosted runner is impractical. None of it is necessary: `brew info --json`
# answers both questions from metadata alone.
#
#   exists   -- the query fails outright for an unknown name
#   kind     -- querying a formula with --cask (or the reverse) errors
#   renamed  -- the returned name/token is CANONICAL, so it differs from the
#               declared one exactly when upstream has renamed it
#
# Usage: bash mac/scripts/check-brewfile.sh [path/to/Brewfile]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="${1:-$SCRIPT_DIR/../Brewfile}"

if [[ ! -f "$BREWFILE" ]]; then
    echo "Brewfile not found: $BREWFILE" >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed; cannot validate the Brewfile." >&2
    exit 1
fi

# Present on GitHub's macOS runners and in the Brewfile itself, but say so
# plainly rather than failing inside the loop with a bare "jq: not found".
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to read brew's JSON output (brew install jq)." >&2
    exit 1
fi

echo "==> Validating $(grep -cE '^[[:space:]]*(brew|cask) ' "$BREWFILE") Brewfile entries"

failures=0

# `brew info` is one network round trip per entry, so this reads the whole
# Brewfile first and reports every problem rather than dying on the first.
while read -r kind name; do
    [[ -z "$name" ]] && continue

    case "$kind" in
        brew) flag="--formula"; query='.formulae[0].name'  ;;
        cask) flag="--cask";    query='.casks[0].token'    ;;
        *)    continue ;;
    esac

    if ! info="$(brew info --json=v2 "$flag" "$name" 2>/dev/null)"; then
        echo "  MISSING  $kind \"$name\" -- Homebrew has no such $kind (removed, or wrong kind?)"
        failures=$((failures + 1))
        continue
    fi

    canonical="$(printf '%s' "$info" | jq -r "$query // empty")"

    if [[ -z "$canonical" ]]; then
        echo "  MISSING  $kind \"$name\" -- Homebrew returned no metadata"
        failures=$((failures + 1))
    elif [[ "$canonical" != "$name" ]]; then
        echo "  RENAMED  $kind \"$name\" is now \"$canonical\" -- update the Brewfile"
        failures=$((failures + 1))
    fi
done < <(sed -nE 's/^[[:space:]]*(brew|cask)[[:space:]]+"([^"]+)".*/\1 \2/p' "$BREWFILE")

if [[ "$failures" -gt 0 ]]; then
    echo "==> $failures Brewfile entr$([[ "$failures" -eq 1 ]] && echo y || echo ies) would break a fresh install" >&2
    exit 1
fi

echo "==> Every Brewfile entry resolves, is the right kind, and is not renamed"
