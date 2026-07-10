#!/usr/bin/env bash
# Sema workspace helper — manages the member repos listed in repos.tsv.
# Each member is a normal independent clone (NOT a submodule) on `main`.
#
# Usage:
#   ws.sh bootstrap          Clone any missing member repos
#   ws.sh update             Fetch + fast-forward each member on its main branch
#   ws.sh status             Short git status for each member
#   ws.sh foreach <cmd...>   Run <cmd> inside each member repo
#   ws.sh pin                Write repos.lock (dir<TAB>repo<TAB>sha) for a snapshot
set -euo pipefail

ORG="sema-lisp"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/repos.tsv"

# Emit "<dir>\t<repo>" for each non-comment manifest line.
members() { grep -vE '^\s*#|^\s*$' "$MANIFEST"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  bootstrap)
    members | while IFS=$'\t' read -r dir repo; do
      if [ -d "$ROOT/$dir/.git" ]; then
        echo "· $dir (present)"
      else
        echo "↓ cloning $ORG/$repo -> $dir"
        git clone "git@github.com:$ORG/$repo.git" "$ROOT/$dir"
      fi
    done
    # Build-cache tooling required by .cargo/config.toml (sccache) and `jake sweep`.
    # The workspace-root .cargo/config.toml sets rustc-wrapper=sccache, so a missing
    # sccache breaks every cargo build under the workspace — install it here.
    if command -v sccache >/dev/null 2>&1; then
      echo "· sccache (present)"
    else
      echo "↓ installing sccache"
      brew install sccache || cargo install sccache
    fi
    if command -v cargo-sweep >/dev/null 2>&1; then
      echo "· cargo-sweep (present)"
    else
      echo "↓ installing cargo-sweep"
      cargo install cargo-sweep
    fi ;;
  update)
    members | while IFS=$'\t' read -r dir repo; do
      [ -d "$ROOT/$dir/.git" ] || { echo "✗ $dir missing (run bootstrap)"; continue; }
      echo "⟳ $dir"; git -C "$ROOT/$dir" pull --ff-only --quiet || echo "  (not fast-forwardable — resolve by hand)"
    done ;;
  status)
    members | while IFS=$'\t' read -r dir repo; do
      [ -d "$ROOT/$dir/.git" ] || { echo "✗ $dir missing"; continue; }
      br="$(git -C "$ROOT/$dir" rev-parse --abbrev-ref HEAD)"
      n="$(git -C "$ROOT/$dir" status --porcelain | wc -l | tr -d ' ')"
      printf '%-18s %-8s %s\n' "$dir" "$br" "$([ "$n" = 0 ] && echo clean || echo "$n changed")"
    done ;;
  foreach)
    members | while IFS=$'\t' read -r dir repo; do
      [ -d "$ROOT/$dir/.git" ] || continue
      echo "=== $dir ==="; ( cd "$ROOT/$dir" && "$@" )
    done ;;
  pin)
    : > "$ROOT/repos.lock"
    members | while IFS=$'\t' read -r dir repo; do
      [ -d "$ROOT/$dir/.git" ] || continue
      sha="$(git -C "$ROOT/$dir" rev-parse HEAD)"
      printf '%s\t%s\t%s\n' "$dir" "$repo" "$sha" >> "$ROOT/repos.lock"
    done
    echo "Wrote repos.lock ($(wc -l < "$ROOT/repos.lock" | tr -d ' ') members)" ;;
  *)
    echo "usage: ws.sh {bootstrap|update|status|foreach <cmd>|pin}" >&2; exit 2 ;;
esac
