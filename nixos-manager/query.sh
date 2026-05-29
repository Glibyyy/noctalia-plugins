#!/usr/bin/env bash
# Query NixOS system state + git repo status.
# Usage: query.sh <flake_dir>
# Output: JSON — no sudo needed, no slow commands.

set -euo pipefail

FLAKE_DIR="${1:-$HOME/nixos-config}"
FLAKE_DIR="${FLAKE_DIR/#\~/$HOME}"

# ── System info (no sudo) ─────────────────────────────────────────
CURRENT_GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -oP 'system-\K\d+') || CURRENT_GEN="?"
GEN_DATE=$(stat -c '%y' /nix/var/nix/profiles/system 2>/dev/null | cut -d. -f1) || GEN_DATE=""
QS_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
KERNEL=$(uname -r 2>/dev/null || echo "unknown")
# Fast store size: count generations instead of du
GEN_COUNT=$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l) || GEN_COUNT="?"

# ── Git repo status ───────────────────────────────────────────────
GIT_BRANCH=""
GIT_DIRTY=false
GIT_DIRTY_COUNT=0
GIT_AHEAD=0
GIT_BEHIND=0
GIT_LAST_COMMIT=""
GIT_LAST_MSG=""
GIT_UNTRACKED=0

if [ -d "$FLAKE_DIR/.git" ]; then
  cd "$FLAKE_DIR"
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  DIRTY_FILES=$(git status --porcelain 2>/dev/null || echo "")
  if [ -n "$DIRTY_FILES" ]; then
    GIT_DIRTY=true
    GIT_DIRTY_COUNT=$(echo "$DIRTY_FILES" | wc -l)
  fi

  UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
  if [ -n "$UNTRACKED_FILES" ]; then
    GIT_UNTRACKED=$(echo "$UNTRACKED_FILES" | wc -l)
  fi

  # Fetch remote (quick, for behind detection)
  git fetch --quiet 2>/dev/null || true
  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
    GIT_BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
  fi

  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "")
  GIT_LAST_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "")
fi

# ── Output JSON ───────────────────────────────────────────────────
export _QS_HOSTNAME="$QS_HOSTNAME" _QS_GEN="$CURRENT_GEN" _QS_GEN_DATE="$GEN_DATE"
export _QS_KERNEL="$KERNEL" _QS_GEN_COUNT="$GEN_COUNT"
export _QS_BRANCH="$GIT_BRANCH" _QS_DIRTY="$GIT_DIRTY" _QS_DIRTY_COUNT="$GIT_DIRTY_COUNT"
export _QS_AHEAD="$GIT_AHEAD" _QS_BEHIND="$GIT_BEHIND"
export _QS_LAST_COMMIT="$GIT_LAST_COMMIT" _QS_LAST_MSG="$GIT_LAST_MSG"
export _QS_UNTRACKED="$GIT_UNTRACKED"

python3 -c "
import json, os
print(json.dumps({
    'system': {
        'hostname': os.environ['_QS_HOSTNAME'],
        'generation': os.environ['_QS_GEN'],
        'genDate': os.environ['_QS_GEN_DATE'],
        'kernel': os.environ['_QS_KERNEL'],
        'genCount': os.environ['_QS_GEN_COUNT']
    },
    'repo': {
        'branch': os.environ['_QS_BRANCH'],
        'dirty': os.environ['_QS_DIRTY'] == 'true',
        'dirtyCount': int(os.environ['_QS_DIRTY_COUNT']),
        'ahead': int(os.environ['_QS_AHEAD']),
        'behind': int(os.environ['_QS_BEHIND']),
        'lastCommit': os.environ['_QS_LAST_COMMIT'],
        'lastMsg': os.environ['_QS_LAST_MSG'],
        'untrackedCount': int(os.environ['_QS_UNTRACKED'])
    }
}))
"
