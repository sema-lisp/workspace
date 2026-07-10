#!/usr/bin/env bash
# Sema workspace disk hygiene — report and reclaim Rust build-cache sprawl across
# EVERY target/ under the workspace (members, worktrees, bare siblings). See
# ../CLAUDE.md "Disk hygiene & build cache".
#
# Usage:
#   disk.sh sizes          Size of every target/ under the workspace + .sccache + free space
#   disk.sh sweep [days]   cargo-sweep stale artifacts older than <days> (default 3) everywhere
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Total KB of all target/ dirs under the workspace (prune so nested paths aren't double-counted).
target_total_kb() {
  local total=0 kb
  while IFS= read -r d; do
    kb="$(du -sk "$d" 2>/dev/null | awk '{print $1}')"
    total=$(( total + ${kb:-0} ))
  done < <(find "$ROOT" -type d -name target -prune 2>/dev/null)
  echo "$total"
}

human() { awk -v k="$1" 'BEGIN{ split("K M G T",u); i=1; while(k>=1024 && i<4){k/=1024;i++} printf "%.1f%s\n", k, u[i] }'; }

cmd="${1:-}"; shift || true
case "$cmd" in
  sizes)
    echo "=== target/ dirs under $ROOT (largest last) ==="
    find "$ROOT" -type d -name target -prune 2>/dev/null -exec du -sh {} + | sort -h
    echo
    echo "target/ total: $(human "$(target_total_kb)")"
    if [ -d "$ROOT/.sccache" ]; then
      echo "sccache cache: $(du -sh "$ROOT/.sccache" 2>/dev/null | awk '{print $1}')  ($ROOT/.sccache)"
    else
      echo "sccache cache: (none yet at $ROOT/.sccache)"
    fi
    echo
    echo "=== free space ==="
    df -h "$ROOT" | tail -n +1
    ;;
  sweep)
    days="${1:-3}"; mode="${2:-}"
    dry=""; case "$mode" in dry|--dry-run|preview) dry="--dry-run";; esac
    command -v cargo-sweep >/dev/null 2>&1 || { echo "cargo-sweep not installed — run: cargo install cargo-sweep (or jake bootstrap)" >&2; exit 2; }
    echo "→ cargo sweep --recursive --hidden --time $days ${dry}  over $ROOT"
    echo "  (removes regenerable artifacts older than $days days; fresh/in-flight builds are kept)"
    # --recursive finds every target/ under ROOT in one pass; --hidden is REQUIRED so it
    # descends into .worktrees/ (recursive skips dot-dirs otherwise); --time keeps last N days.
    if [ -n "$dry" ]; then
      cargo sweep --recursive --hidden --time "$days" --dry-run "$ROOT"
      echo; echo "(dry-run — nothing deleted; drop 'dry' to reclaim)"
    else
      before_kb="$(target_total_kb)"
      cargo sweep --recursive --hidden --time "$days" "$ROOT"
      after_kb="$(target_total_kb)"
      reclaimed_kb=$(( before_kb - after_kb ))
      echo
      echo "target/ total: $(human "$before_kb") → $(human "$after_kb")   (reclaimed $(human "$(( reclaimed_kb < 0 ? 0 : reclaimed_kb ))"))"
    fi
    ;;
  *)
    echo "usage: disk.sh {sizes|sweep [days]}" >&2; exit 2 ;;
esac
