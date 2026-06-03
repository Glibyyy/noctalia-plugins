#!/usr/bin/env bash
# Query NixOS system state + git repo status.
# Usage: query.sh <flake_dir>
# Output: JSON — no sudo needed, no slow commands.

set -euo pipefail

FLAKE_DIR="${1:-$HOME/nixos-config}"
FLAKE_DIR="${FLAKE_DIR/#\~/$HOME}"
AUTO_FETCH="${2:-1}"

# ── System info (no sudo) ─────────────────────────────────────────
CURRENT_GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -oP 'system-\K\d+') || CURRENT_GEN="?"
GEN_DATE=$(stat -c '%y' /nix/var/nix/profiles/system 2>/dev/null | cut -d. -f1) || GEN_DATE=""
QS_HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
KERNEL=$(uname -r 2>/dev/null || echo "unknown")
# Generation count
GEN_COUNT=$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l) || GEN_COUNT="?"
# Store size via nix narSize sum (fast, ~1-2s)
STORE_SIZE=$(nix path-info --all --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(v.get('narSize',0) for v in d.values()))" 2>/dev/null) || STORE_SIZE="0"

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
  if [ "$AUTO_FETCH" = "1" ]; then
    git fetch --quiet 2>/dev/null || true
  fi
  UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
    GIT_BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
  fi

  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "")
  GIT_LAST_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "")

  # Detect pull conflict: dirty files that overlap with incoming remote changes
  GIT_PULL_CONFLICT=false
  if [ "$GIT_DIRTY" = "true" ] && [ "$GIT_BEHIND" -gt 0 ] && [ -n "$UPSTREAM" ]; then
    LOCAL_FILES=$(echo "$DIRTY_FILES" | awk '{print $2}' | sort)
    REMOTE_FILES=$(git diff --name-only "HEAD..$UPSTREAM" 2>/dev/null | sort)
    OVERLAP=$(comm -12 <(echo "$LOCAL_FILES") <(echo "$REMOTE_FILES"))
    if [ -n "$OVERLAP" ]; then
      GIT_PULL_CONFLICT=true
    fi
  fi
fi

# ── GC estimate (fast — no actual deletion) ──────────────────────
GC_DEAD=$(nix-store --gc --print-dead 2>/dev/null | grep '^/nix/store' || true)
if [ -n "$GC_DEAD" ]; then
  GC_PATHS=$(echo "$GC_DEAD" | wc -l)
  GC_BYTES=$(echo "$GC_DEAD" | xargs -r nix-store -q --size 2>/dev/null | awk '{sum+=$1} END {print sum+0}' || echo 0)
  GC_FREED=$(awk "BEGIN {b=${GC_BYTES:-0}; if(b>=1073741824) printf \"%.1f GB\",b/1073741824; else if(b>=1048576) printf \"%.0f MB\",b/1048576; else printf \"\"}")
else
  GC_PATHS=0
  GC_FREED="0 B"
fi

# ── Output JSON ───────────────────────────────────────────────────
export _QS_HOSTNAME="$QS_HOSTNAME" _QS_GEN="$CURRENT_GEN" _QS_GEN_DATE="$GEN_DATE"
export _QS_KERNEL="$KERNEL" _QS_GEN_COUNT="$GEN_COUNT" _QS_STORE_SIZE="$STORE_SIZE"
export _QS_BRANCH="$GIT_BRANCH" _QS_DIRTY="$GIT_DIRTY" _QS_DIRTY_COUNT="$GIT_DIRTY_COUNT"
export _QS_AHEAD="$GIT_AHEAD" _QS_BEHIND="$GIT_BEHIND"
export _QS_LAST_COMMIT="$GIT_LAST_COMMIT" _QS_LAST_MSG="$GIT_LAST_MSG"
export _QS_UNTRACKED="$GIT_UNTRACKED"
export _QS_CHANGED_RAW="$DIRTY_FILES"
export _QS_PULL_CONFLICT="${GIT_PULL_CONFLICT:-false}"
export _QS_GC_FREED="$GC_FREED" _QS_GC_PATHS="$GC_PATHS"

python3 -c "
import json, os
changed_raw = os.environ.get('_QS_CHANGED_RAW', '')
changed_files = []
for line in changed_raw.split('\n'):
    line = line.rstrip()
    if len(line) < 4: continue
    status = line[:2].strip()
    path = line[3:]
    changed_files.append({'status': status, 'file': path})

print(json.dumps({
    'system': {
        'hostname': os.environ['_QS_HOSTNAME'],
        'generation': os.environ['_QS_GEN'],
        'genDate': os.environ['_QS_GEN_DATE'],
        'kernel': os.environ['_QS_KERNEL'],
        'genCount': os.environ['_QS_GEN_COUNT'],
        'storeSize': int(os.environ.get('_QS_STORE_SIZE', '0'))
    },
    'gc': {
        'storeFreed': os.environ['_QS_GC_FREED'],
        'pathCount': int(os.environ['_QS_GC_PATHS'])
    },
    'repo': {
        'branch': os.environ['_QS_BRANCH'],
        'dirty': os.environ['_QS_DIRTY'] == 'true',
        'dirtyCount': int(os.environ['_QS_DIRTY_COUNT']),
        'ahead': int(os.environ['_QS_AHEAD']),
        'behind': int(os.environ['_QS_BEHIND']),
        'lastCommit': os.environ['_QS_LAST_COMMIT'],
        'lastMsg': os.environ['_QS_LAST_MSG'],
        'untrackedCount': int(os.environ['_QS_UNTRACKED']),
        'pullConflict': os.environ.get('_QS_PULL_CONFLICT', 'false') == 'true',
        'changedFiles': changed_files
    }
}))
"
