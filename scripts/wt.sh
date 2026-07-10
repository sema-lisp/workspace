#!/usr/bin/env bash
# Sema workspace worktree lifecycle — the ONLY sanctioned way to create/remove
# git worktrees in this workspace. Enforces the hard rule that every worktree
# lives under $ROOT/.worktrees/ (see ../CLAUDE.md "Worktrees — HARD REQUIREMENT").
#
# Usage:
#   wt.sh new <name> [branch] [member]   Create $ROOT/.worktrees/<name>
#                                        (branch defaults to <name>, member to sema)
#   wt.sh rm  <name>                     cargo-clean its target, then remove + prune
#   wt.sh list                           List all worktrees; flag any outside .worktrees/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WT_DIR="$ROOT/.worktrees"
MANIFEST="$ROOT/repos.tsv"

# Emit "<dir>\t<repo>" for each non-comment manifest line.
members() { grep -vE '^\s*#|^\s*$' "$MANIFEST"; }

die() { echo "wt.sh: $*" >&2; exit 2; }

# Reject empty names and anything that could escape .worktrees/ (slashes, ..).
validate_name() {
  local name="$1"
  [ -n "$name" ] || die "worktree name is required (usage: wt.sh new <name> [branch] [member])"
  case "$name" in
    */*|*..*|.*) die "invalid worktree name '$name' — no slashes, no leading dot, no '..'";;
  esac
}

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    # Args: <name> [branch=<b>] [member=<m>]. The key=value form is empty-safe —
    # jake collapses an empty {{branch}} to nothing, so a bare positional would
    # shift; `branch=` survives as one token even when the value is empty.
    name=""; branch=""; member="sema"
    for a in "$@"; do
      case "$a" in
        branch=*) branch="${a#branch=}";;
        member=*) member="${a#member=}";;
        *=*)      die "unknown argument '$a' (expected branch=… or member=…)";;
        *)        [ -z "$name" ] && name="$a" || die "unexpected extra argument '$a'";;
      esac
    done
    [ -n "$member" ] || member="sema"
    validate_name "$name"
    [ -z "$branch" ] && branch="$name"
    [ -d "$ROOT/$member/.git" ] || die "member '$member' not found at $ROOT/$member (run: jake bootstrap)"
    dest="$WT_DIR/$name"
    [ -e "$dest" ] && die "$dest already exists"
    mkdir -p "$WT_DIR"
    echo "→ git worktree add $dest -b $branch  (member: $member)"
    git -C "$ROOT/$member" worktree add "$dest" -b "$branch"
    echo "✓ created $dest on branch $branch"
    ;;
  rm)
    name="${1:-}"
    validate_name "$name"
    dest="$WT_DIR/$name"
    [ -e "$dest" ] || die "no worktree at $dest (use 'wt.sh list' to see all)"
    # Resolve the owning repo: a worktree's .git is a file "gitdir: <path>/.git/worktrees/<id>".
    gitdir="$(sed -n 's/^gitdir: //p' "$dest/.git" 2>/dev/null || true)"
    owner=""
    case "$gitdir" in
      */.git/worktrees/*) owner="${gitdir%%/.git/worktrees/*}";;
    esac
    echo "→ reclaiming build artifacts (cargo clean) in $dest"
    ( cd "$dest" && cargo clean ) 2>/dev/null || rm -rf "$dest/target"
    if [ -n "$owner" ]; then
      echo "→ git worktree remove (owner: $owner)"
      git -C "$owner" worktree remove --force "$dest"
      git -C "$owner" worktree prune
    else
      echo "! could not resolve owning repo from $dest/.git — falling back to sema"
      git -C "$ROOT/sema" worktree remove --force "$dest" || rm -rf "$dest"
      git -C "$ROOT/sema" worktree prune || true
    fi
    echo "✓ removed $dest"
    ;;
  list)
    echo "Policy: worktrees MUST live under $WT_DIR"
    echo
    seen_violation=0
    members | while IFS=$'\t' read -r dir repo; do
      [ -d "$ROOT/$dir/.git" ] || continue
      # Only members that actually have worktrees produce >1 line.
      lines="$(git -C "$ROOT/$dir" worktree list --porcelain 2>/dev/null | grep -c '^worktree ' || true)"
      [ "${lines:-0}" -le 1 ] && continue
      echo "=== $dir ==="
      git -C "$ROOT/$dir" worktree list | while read -r path rest; do
        # The primary checkout is the member dir itself — skip the policy check for it.
        if [ "$path" = "$ROOT/$dir" ]; then
          printf '   %s %s\n' "$path" "$rest"
        elif case "$path" in "$WT_DIR"/*) true;; *) false;; esac; then
          printf ' ✓ %s %s\n' "$path" "$rest"
        else
          printf ' ✗ OUT-OF-POLICY  %s %s\n' "$path" "$rest"
        fi
      done
    done
    echo
    echo "✗ = worktree outside .worktrees/ (WIP — leave untouched; do not create new ones there)"
    ;;
  *)
    echo "usage: wt.sh {new <name> [branch] [member]|rm <name>|list}" >&2; exit 2 ;;
esac
