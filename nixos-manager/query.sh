#!/usr/bin/env bash
# Query NixOS system state + git repo status.
# Usage: query.sh <flake_dir>
# Output: JSON with system info, repo status, generation info.

set -euo pipefail

FLAKE_DIR="${1:-$HOME/nixos-config}"
FLAKE_DIR="${FLAKE_DIR/#\~/$HOME}"

# ── System info ───────────────────────────────────────────────────
CURRENT_GEN=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null \
  | grep '(current)' | awk '{print $1}') || CURRENT_GEN="?"
GEN_DATE=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null \
  | grep '(current)' | awk '{print $2, $3}') || GEN_DATE=""
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
KERNEL=$(uname -r 2>/dev/null || echo "unknown")
STORE_PATH=$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || echo "")

# ── Git repo status ───────────────────────────────────────────────
GIT_BRANCH=""
GIT_DIRTY="false"
GIT_DIRTY_COUNT=0
GIT_AHEAD=0
GIT_BEHIND=0
GIT_LAST_COMMIT=""
GIT_LAST_MSG=""

if [ -d "$FLAKE_DIR/.git" ]; then
  cd "$FLAKE_DIR"
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # Dirty files
  DIRTY_FILES=$(git status --porcelain 2>/dev/null || echo "")
  if [ -n "$DIRTY_FILES" ]; then
    GIT_DIRTY="true"
    GIT_DIRTY_COUNT=$(echo "$DIRTY_FILES" | wc -l)
  fi

  # Ahead/behind remote (fetch first, quick dry-run)
  git fetch --quiet 2>/dev/null || true
  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
    GIT_BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
  fi

  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "")
  GIT_LAST_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "")
fi

# ── Store size ────────────────────────────────────────────────────
STORE_SIZE=$(du -sh /nix/store 2>/dev/null | awk '{print $1}') || STORE_SIZE="?"

# ── Output JSON ───────────────────────────────────────────────────
python3 -c "
import json
print(json.dumps({
    'system': {
        'hostname': '$HOSTNAME',
        'generation': '$CURRENT_GEN',
        'genDate': '$GEN_DATE',
        'kernel': '$KERNEL',
        'storePath': '$STORE_PATH',
        'storeSize': '$STORE_SIZE'
    },
    'repo': {
        'branch': '$GIT_BRANCH',
        'dirty': $GIT_DIRTY,
        'dirtyCount': $GIT_DIRTY_COUNT,
        'ahead': $GIT_AHEAD,
        'behind': $GIT_BEHIND,
        'lastCommit': '$GIT_LAST_COMMIT',
        'lastMsg': $(json.dumps('$GIT_LAST_MSG'))
    }
}))
"
