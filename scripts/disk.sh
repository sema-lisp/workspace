#!/usr/bin/env bash
# Sema workspace disk hygiene — report and reclaim Rust build-cache sprawl across
# EVERY target/ under the workspace (members, worktrees, bare siblings). See
# ../CLAUDE.md "Disk hygiene & build cache".
#
# Usage:
#   disk.sh sizes          Size of every target/ under the workspace + .sccache + free space
#   disk.sh sweep [days]   cargo-sweep stale artifacts older than <days> (default 3) everywhere
#   disk.sh cap [size]     cargo-sweep each target/ down to <size> (default 10GB), oldest first
#
# Use `cap` when `sweep` reclaims nothing. During a release every artifact is fresh, so
# an age-based sweep is a no-op while target/ still balloons — cargo never GCs artifacts
# a rebuild superseded, and each version bump produces a fresh set. A size cap evicts the
# least-recently-used artifacts regardless of age, which is the only thing that helps.
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

need_cargo_sweep() {
  command -v cargo-sweep >/dev/null 2>&1 ||
    { echo "cargo-sweep not installed — run: cargo install cargo-sweep (or jake bootstrap)" >&2; exit 2; }
}

# Run cargo-sweep over every target/ under ROOT and report what it reclaimed.
# $1 = selector flag and value (e.g. "--time 3"), $2 = "--dry-run" or empty.
# --recursive finds every target/ under ROOT in one pass; --hidden is REQUIRED so it
# descends into .worktrees/ (recursive skips dot-dirs otherwise).
run_sweep() {
  local selector="$1" dry="$2"
  # shellcheck disable=SC2086 # selector is two intentional words
  if [ -n "$dry" ]; then
    cargo sweep --recursive --hidden $selector --dry-run "$ROOT"
    echo; echo "(dry-run — nothing deleted; drop 'dry' to reclaim)"
  else
    local before_kb after_kb reclaimed_kb
    before_kb="$(target_total_kb)"
    cargo sweep --recursive --hidden $selector "$ROOT"
    after_kb="$(target_total_kb)"
    reclaimed_kb=$(( before_kb - after_kb ))
    echo
    echo "target/ total: $(human "$before_kb") → $(human "$after_kb")   (reclaimed $(human "$(( reclaimed_kb < 0 ? 0 : reclaimed_kb ))"))"
  fi
}

dry_flag() { case "${1:-}" in dry|--dry-run|preview) echo "--dry-run";; *) echo "";; esac; }

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
    days="${1:-3}"; dry="$(dry_flag "${2:-}")"
    need_cargo_sweep
    echo "→ cargo sweep --recursive --hidden --time $days ${dry}  over $ROOT"
    echo "  (removes regenerable artifacts older than $days days; fresh/in-flight builds are kept)"
    run_sweep "--time $days" "$dry"
    ;;
  cap)
    max="${1:-10GB}"; dry="$(dry_flag "${2:-}")"
    need_cargo_sweep
    echo "→ cargo sweep --recursive --hidden --maxsize $max ${dry}  over $ROOT"
    echo "  (caps EACH target/ at $max, evicting least-recently-used artifacts first —"
    echo "   works when 'sweep' cannot, because it ignores age)"
    run_sweep "--maxsize $max" "$dry"
    ;;
  *)
    echo "usage: disk.sh {sizes|sweep [days] [dry]|cap [size] [dry]}" >&2; exit 2 ;;
esac
