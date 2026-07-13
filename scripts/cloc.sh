#!/usr/bin/env bash
# Honest LOC count across the workspace.
#
# cloc's own --exclude-list-file matches full paths (won't prune trees), so we
# read the NAMES from .clocignore and feed them to --exclude-dir, which does
# prune. Binary/generated artifacts outside those dirs are dropped by extension.
# Any extra args are passed straight through to cloc (e.g. --by-file, --json).
#
# Usage: scripts/cloc.sh [extra cloc args...]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IGNORE="$ROOT/.clocignore"

if ! command -v cloc >/dev/null 2>&1; then
  echo "cloc not found. Install with: brew install --HEAD cloc" >&2
  exit 127
fi

# Directory/file NAMES to prune, comma-joined (comments and blanks stripped).
EXCLUDE_DIRS="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$IGNORE" | paste -sd, -)"

exec cloc "$ROOT" \
  --exclude-dir="$EXCLUDE_DIRS" \
  --exclude-ext=wasm,mp4,map \
  --quiet "$@"
